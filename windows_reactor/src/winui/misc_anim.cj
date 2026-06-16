package windows_reactor.winui

import windows_core.{HString, winrtBorrowGenericIn}
import windows_reactor.core.{ImplicitTransitions, LayoutAnimationConfig, AnimationConfig, Easing}
import windows_sys.Microsoft.UI.Xaml.{FrameworkElement}
import windows_sys.Microsoft.UI.Xaml.Hosting.{ElementCompositionPreview}
import windows_sys.Microsoft.UI.Composition.{
    Visual, CompositionObject, Compositor, CompositionAnimation, CompositionEasingFunction,
    KeyFrameAnimation, ImplicitAnimationCollection
}
import windows_sys.impl.Microsoft_UI_Composition.{Microsoft_UI_Composition_ICompositionAnimationBase as ICompositionAnimationBase}
import windows_sys.impl.Windows_Foundation.{Windows_Foundation_TimeSpan}
import windows_sys.impl.Windows_Foundation_Collections.{Windows_Foundation_Collections_IMap_2 as XamlIMap}
import windows_sys.impl.Windows_Foundation_Numerics.{Windows_Foundation_Numerics_Vector2, Windows_Foundation_Numerics_Vector3}

// ============================================================================
// Composition animation family — free-function implementations.
//
// priority: polish (off the parity critical path). Implicit transitions and
// one-shot property animations reach the element's composition Visual via
// ElementCompositionPreview.GetElementVisual and drive the Microsoft.UI.
// Composition key-frame / implicit-animation surface.
//
// Ported faithfully from the reference backend's apply_implicit_transitions /
// run_property_animation_inner / easing_for / anim_duration_to_timespan.
//
// Projection ABI (verified against windows_sys, Microsoft.UI.Composition):
//   - ElementCompositionPreview.GetElementVisual(UIElement) -> Visual.
//   - Visual viewed as CompositionObject exposes Compositor (get) and
//     StartAnimation(HString, CompositionAnimation); Visual exposes Scale
//     (Vector3) and CenterPoint (Vector3) mut props.
//   - Compositor.CreateScalarKeyFrameAnimation / CreateVector3KeyFrameAnimation /
//     CreateCubicBezierEasingFunction / CreateLinearEasingFunction (high-level).
//     CreateImplicitAnimationCollection is on ICompositor2 (asICompositor2()).
//   - The leaf key-frame animations are viewed as the high-level
//     KeyFrameAnimation to reach Duration (mut prop),
//     InsertExpressionKeyFrameWithEasingFunction, asICompositionAnimation2()
//     (SetTarget, raw vtable) and asICompositionAnimationBase() (the map value).
//     They expose their own typed InsertKeyFrameWithEasingFunction
//     (Scalar: Float32; Vector3: Vector3).
//   - ImplicitAnimationCollection.asIMap() -> IMap<HString, ICompositionAnimationBase>
//     with Insert(key, value) (unsafe). ICompositionObject2.SetImplicitAnimations
//     (raw vtable) attaches/clears the collection.
//
// All HRESULTs surface as exceptions; the backend delegate wraps these calls in
// try/catch (matching the reference `if let Err(e) = ... { eprintln!(...) }`).
// ============================================================================

type ImplicitAnimationMap = XamlIMap<HString, ICompositionAnimationBase>

// Convert a reactor duration in milliseconds to a WinRT TimeSpan (100ns ticks),
// mirroring anim_duration_to_timespan. Negative / NaN durations clamp to 0.
func animDurationToTimeSpan(durationMs: Float64): Windows_Foundation_TimeSpan {
    var ts = Windows_Foundation_TimeSpan()
    ts.Duration = if (durationMs.isNaN() || durationMs <= 0.0) {
        0
    } else {
        Int64(durationMs * 10000.0)
    }
    ts
}

// Build the composition easing function for a reactor Easing, mirroring
// easing_for. Linear uses CreateLinearEasingFunction; the others use the
// CSS-standard cubic-bezier control points. Returned as an owned
// CompositionEasingFunction (caller closes). `compositor` is borrowed.
func easingFor(compositor: Compositor, easing: Easing): CompositionEasingFunction {
    match (easing) {
        case Linear =>
            let lin = compositor.CreateLinearEasingFunction()
            try {
                return CompositionEasingFunction.fromAbiTake(
                    queryRequired(lin.asRaw(), CompositionEasingFunction.iid(),
                        "Microsoft.UI.Composition.ICompositionEasingFunction"))
            } finally {
                lin.close()
            }
        case EaseIn =>
            cubicEasing(compositor, 0.42, 0.0, 1.0, 1.0)
        case EaseInOut =>
            cubicEasing(compositor, 0.42, 0.0, 0.58, 1.0)
        case EaseOut =>
            cubicEasing(compositor, 0.0, 0.0, 0.58, 1.0)
    }
}

func cubicEasing(compositor: Compositor, x1: Float64, y1: Float64, x2: Float64, y2: Float64): CompositionEasingFunction {
    let cubic = compositor.CreateCubicBezierEasingFunction(vec2(x1, y1), vec2(x2, y2))
    try {
        return CompositionEasingFunction.fromAbiTake(
            queryRequired(cubic.asRaw(), CompositionEasingFunction.iid(),
                "Microsoft.UI.Composition.ICompositionEasingFunction"))
    } finally {
        cubic.close()
    }
}

// Install (or clear) implicit composition transitions on the element's Visual.
// `transitions` is None (or every slot empty) to clear the implicit-animation
// collection. Mirrors apply_implicit_transitions.
func animSetImplicitTransitions(handle: Handle, transitions: ?ImplicitTransitions): Unit {
    let visual = elementVisual(handle)
    try {
        let obj2 = visual.asICompositionObject2()
        try {
            let active = match (transitions) {
                case Some(t) where !t.isEmpty() => t
                case _ =>
                    // No transitions, or every slot empty: clear the collection.
                    checkHRESULT(unsafe { obj2.SetImplicitAnimations(CPointer<Unit>()) },
                        "ICompositionObject2.SetImplicitAnimations(null)")
                    return
            }

            let compObj = compositionObjectOf(visual)
            try {
                let compositor = compObj.Compositor
                try {
                    let collection = createImplicitCollection(compositor)
                    try {
                        let map = collection.asIMap()
                        try {
                            // The DSL transitions only carry duration, so easing is
                            // fixed to EaseOut (the standard implicit-transition curve).
                            match (active.opacity) {
                                case Some(s) => insertImplicit(map, compositor, "Opacity", s.durationMs, true)
                                case None => ()
                            }
                            match (active.rotation) {
                                case Some(s) => insertImplicit(map, compositor, "RotationAngleInDegrees", s.durationMs, true)
                                case None => ()
                            }
                            match (active.scale) {
                                case Some(v) => insertImplicit(map, compositor, "Scale", v.durationMs, false)
                                case None => ()
                            }
                            match (active.translation) {
                                // KNOWN LIMITATION (mirrors the reference): `Offset`
                                // collides with XAML layout; the correct target is the
                                // synthetic `Translation` channel.
                                case Some(v) => insertImplicit(map, compositor, "Offset", v.durationMs, false)
                                case None => ()
                            }
                        } finally {
                            map.close()
                        }
                        checkHRESULT(unsafe { obj2.SetImplicitAnimations(collection.asRaw()) },
                            "ICompositionObject2.SetImplicitAnimations")
                    } finally {
                        collection.close()
                    }
                } finally {
                    compositor.close()
                }
            } finally {
                compObj.close()
            }
        } finally {
            obj2.close()
        }
    } finally {
        visual.close()
    }
}

// Configure the layout animation flag. The actual offset animation is triggered
// by the reconciler when Canvas.Left / Canvas.Top changes.
func animSetLayout(handle: Handle, config: ?LayoutAnimationConfig): Unit {
    let _ = handle
    let _ = config
}

// Best-effort cleanup for layout translation animations before a control is
// destroyed or reused for another move.
func animStopLayoutTranslation(handle: Handle): Unit {
    let visual = elementVisual(handle)
    try {
        let compObj = compositionObjectOf(visual)
        try {
            stopAnimation(compObj, "Translation")
        } finally {
            compObj.close()
        }
    } finally {
        visual.close()
    }
}

// Animate a layout jump by placing the element at its final Canvas.Left/Top and
// running a compositor Translation animation from the old visual offset back to
// zero. This keeps layout correct immediately while movement is GPU-composited.
func animRunLayoutTranslation(handle: Handle, dx: Float64, dy: Float64,
                              config: LayoutAnimationConfig): Unit {
    if (!config.animateOffset) {
        return
    }
    if (dx == 0.0 && dy == 0.0) {
        return
    }

    let ui = handleUIElementOwned(handle)
    try {
        // Only the legacy ElementCompositionPreview protocol may drive the
        // hand-off visual's "Translation" channel here. Also writing the
        // UIElement facade property (ui.Translation) makes XAML's facade
        // engine and this manual StartAnimation double-drive the same
        // property, which fail-fasts inside CoreMessagingXP under churn.
        ElementCompositionPreview.SetIsTranslationEnabled(ui, true)

        let visual = ElementCompositionPreview.GetElementVisual(ui)
        try {
            let compObj = compositionObjectOf(visual)
            try {
                stopAnimation(compObj, "Translation")
                let compositor = compObj.Compositor
                try {
                    runLayoutTranslationAnimation(compObj, compositor, dx, dy, config)
                } finally {
                    compositor.close()
                }
            } finally {
                compObj.close()
            }
        } finally {
            visual.close()
        }
    } finally {
        ui.close()
    }
}

// Run a one-shot property animation (opacity / scale key-frames) on the
// element's Visual. `config` is None for no animation. Mirrors
// run_property_animation_inner.
func animRunProperty(handle: Handle, config: ?AnimationConfig): Unit {
    let cfg = match (config) {
        case Some(c) => c
        case None => return
    }
    let visual = elementVisual(handle)
    try {
        let compObj = compositionObjectOf(visual)
        try {
            let compositor = compObj.Compositor
            try {
                match (cfg.opacity) {
                    case Some(opacity) => runOpacityAnimation(compObj, compositor, Float32(opacity), cfg)
                    case None => ()
                }
                match (cfg.scale) {
                    case Some(scale) => runScaleAnimation(handle, visual, compObj, compositor, scale, cfg)
                    case None => ()
                }
            } finally {
                compositor.close()
            }
        } finally {
            compObj.close()
        }
    } finally {
        visual.close()
    }
}

// ── private helpers ─────────────────────────────────────────────────────────

func vec2(x: Float64, y: Float64): Windows_Foundation_Numerics_Vector2 {
    var v = Windows_Foundation_Numerics_Vector2()
    v.X = Float32(x)
    v.Y = Float32(y)
    v
}

func vec3(x: Float32, y: Float32, z: Float32): Windows_Foundation_Numerics_Vector3 {
    var v = Windows_Foundation_Numerics_Vector3()
    v.X = x
    v.Y = y
    v.Z = z
    v
}

// Resolve the element's composition Visual via ElementCompositionPreview. The
// handle's identity is QI'd to the high-level UIElement (the static's parameter
// type). Caller owns the returned Visual.
func elementVisual(handle: Handle): Visual {
    let ui = handleUIElementOwned(handle)
    try {
        return ElementCompositionPreview.GetElementVisual(ui)
    } finally {
        ui.close()
    }
}

// View a Visual's identity as the CompositionObject surface (Compositor /
// StartAnimation). Caller owns the returned wrapper.
func compositionObjectOf(visual: Visual): CompositionObject {
    CompositionObject.fromAbiTake(
        queryRequired(visual.asRaw(), CompositionObject.iid(),
            "Microsoft.UI.Composition.ICompositionObject"))
}

// Create an implicit-animation collection from the compositor (ICompositor2 raw
// vtable; no high-level wrapper exists). Caller owns the returned collection.
func createImplicitCollection(compositor: Compositor): ImplicitAnimationCollection {
    let comp2 = compositor.asICompositor2()
    try {
        var raw = CPointer<Unit>()
        checkHRESULT(unsafe { comp2.CreateImplicitAnimationCollection(CPointer<CPointer<Unit>>(inout raw)) },
            "ICompositor2.CreateImplicitAnimationCollection")
        return ImplicitAnimationCollection.fromAbiTake(raw)
    } finally {
        comp2.close()
    }
}

// Set Duration on a leaf key-frame animation (viewed via its identity as the
// high-level KeyFrameAnimation class).
func setAnimationDuration(animRaw: CPointer<Unit>, durationMs: Float64): Unit {
    let kfa = KeyFrameAnimation.viewOf(animRaw)
    kfa.Duration = animDurationToTimeSpan(durationMs)
}

// Set the ICompositionAnimation2.Target string on a leaf animation via the raw
// vtable (no high-level Target prop exists). `animRaw` is the leaf's identity.
func setAnimationTarget(animRaw: CPointer<Unit>, target: HString): Unit {
    let kfa = KeyFrameAnimation.viewOf(animRaw)
    let a2 = kfa.asICompositionAnimation2()
    try {
        try (borrow = winrtBorrowGenericIn<HString>(target)) {
            checkHRESULT(unsafe { a2.SetTarget(borrow.asRaw()) }, "ICompositionAnimation2.SetTarget")
        }
    } finally {
        a2.close()
    }
}

// Insert one implicit transition channel into the collection map. Builds a
// scalar (isScalar) or vector3 key-frame animation that expression-animates to
// `this.FinalValue` over `durationMs` with the standard EaseOut curve, sets its
// Target, and inserts it keyed by `target`. Mirrors the `insert` closure in
// apply_implicit_transitions.
func insertImplicit(map: ImplicitAnimationMap, compositor: Compositor, target: String,
                    durationMs: Float64, isScalar: Bool): Unit {
    let easing = easingFor(compositor, Easing.EaseOut)
    try {
        let targetHs = HString(target)
        try {
            if (isScalar) {
                let anim = compositor.CreateScalarKeyFrameAnimation()
                try {
                    buildExpressionAnim(anim.asRaw(), durationMs, targetHs, easing, map)
                } finally {
                    anim.close()
                }
            } else {
                let anim = compositor.CreateVector3KeyFrameAnimation()
                try {
                    buildExpressionAnim(anim.asRaw(), durationMs, targetHs, easing, map)
                } finally {
                    anim.close()
                }
            }
        } finally {
            targetHs.close()
        }
    } finally {
        easing.close()
    }
}

// Configure a leaf animation (by raw identity) for an implicit transition:
// Duration, the `this.FinalValue` expression key-frame, the Target, then insert
// the animation (as its ICompositionAnimationBase) into the collection map.
func buildExpressionAnim(animRaw: CPointer<Unit>, durationMs: Float64, targetHs: HString,
                         easing: CompositionEasingFunction, map: ImplicitAnimationMap): Unit {
    setAnimationDuration(animRaw, durationMs)
    let kfa = KeyFrameAnimation.viewOf(animRaw)
    kfa.InsertExpressionKeyFrameWithEasingFunction(1.0f32, HString("this.FinalValue"), easing)
    setAnimationTarget(animRaw, targetHs)
    let base = kfa.asICompositionAnimationBase()
    try {
        // Raw IMap<HString, ICompositionAnimationBase>.Insert(key, value, out replaced).
        var replaced = false
        unsafe { map.Insert(targetHs.asRaw(), base.asRaw(), CPointer<Bool>(inout replaced)) }
    } finally {
        base.close()
    }
}

// Run a scalar Opacity key-frame animation to `targetValue` over the config
// duration with the config easing, then start it on the visual.
func runOpacityAnimation(compObj: CompositionObject, compositor: Compositor,
                         targetValue: Float32, cfg: AnimationConfig): Unit {
    let anim = compositor.CreateScalarKeyFrameAnimation()
    try {
        setAnimationDuration(anim.asRaw(), cfg.durationMs)
        let easing = easingFor(compositor, cfg.easing)
        try {
            anim.InsertKeyFrameWithEasingFunction(1.0f32, targetValue, easing)
        } finally {
            easing.close()
        }
        startAnimation(compObj, "Opacity", anim.asRaw())
    } finally {
        anim.close()
    }
}

// Run a uniform scale key-frame animation. Pivots around the element's centre
// (CenterPoint) when it has been laid out (ActualWidth/Height > 0); the previous
// CenterPoint is reused otherwise. Preserves the current Scale.Z. Mirrors the
// scale branch of run_property_animation_inner.
func runScaleAnimation(handle: Handle, visual: Visual, compObj: CompositionObject,
                       compositor: Compositor, scale: Float64, cfg: AnimationConfig): Unit {
    match (actualSize(handle)) {
        case Some((w, h)) where w > 0.0 && h > 0.0 =>
            visual.CenterPoint = vec3(Float32(w / 2.0), Float32(h / 2.0), 0.0f32)
        case _ => ()
    }
    let currentZ = visual.Scale.Z
    let anim = compositor.CreateVector3KeyFrameAnimation()
    try {
        setAnimationDuration(anim.asRaw(), cfg.durationMs)
        let s = Float32(scale)
        let easing = easingFor(compositor, cfg.easing)
        try {
            anim.InsertKeyFrameWithEasingFunction(1.0f32, vec3(s, s, currentZ), easing)
        } finally {
            easing.close()
        }
        startAnimation(compObj, "Scale", anim.asRaw())
    } finally {
        anim.close()
    }
}

// Force a hand-off visual's Translation back to (0,0,0) — used to clear a residual
// offset left by a slide that was interrupted/superseded under rapid input. Driven
// through the same ElementCompositionPreview + StartAnimation path as the slide (a
// 1 ms key-frame to zero); the UIElement Translation FACADE is deliberately NOT
// written (that double-drives the property and fail-fasts CoreMessagingXP).
func animSnapLayoutTranslation(handle: Handle): Unit {
    let ui = handleUIElementOwned(handle)
    try {
        ElementCompositionPreview.SetIsTranslationEnabled(ui, true)
        let visual = ElementCompositionPreview.GetElementVisual(ui)
        try {
            let compObj = compositionObjectOf(visual)
            try {
                stopAnimation(compObj, "Translation")
                let compositor = compObj.Compositor
                try {
                    let anim = compositor.CreateVector3KeyFrameAnimation()
                    try {
                        setAnimationDuration(anim.asRaw(), 1.0)
                        anim.InsertKeyFrame(1.0f32, vec3(0.0f32, 0.0f32, 0.0f32))
                        startAnimation(compObj, "Translation", anim.asRaw())
                    } finally {
                        anim.close()
                    }
                } finally {
                    compositor.close()
                }
            } finally {
                compObj.close()
            }
        } finally {
            visual.close()
        }
    } finally {
        ui.close()
    }
}

func runLayoutTranslationAnimation(compObj: CompositionObject, compositor: Compositor,
                                   dx: Float64, dy: Float64,
                                   cfg: LayoutAnimationConfig): Unit {
    let anim = compositor.CreateVector3KeyFrameAnimation()
    try {
        setAnimationDuration(anim.asRaw(), cfg.durationMs)
        let easing = easingFor(compositor, Easing.EaseOut)
        try {
            anim.InsertKeyFrame(0.0f32, vec3(Float32(dx), Float32(dy), 0.0f32))
            anim.InsertKeyFrameWithEasingFunction(1.0f32, vec3(0.0f32, 0.0f32, 0.0f32), easing)
        } finally {
            easing.close()
        }
        startAnimation(compObj, "Translation", anim.asRaw())
    } finally {
        anim.close()
    }
}

// Read the laid-out (ActualWidth, ActualHeight) of the control, or None if the
// FrameworkElement QI fails. Mirrors the reference's
// `ui.cast::<IFrameworkElement>()...get_ActualWidth/Height`.
func actualSize(handle: Handle): ?(Float64, Float64) {
    try {
        let fe = FrameworkElement.fromAbiTake(
            queryRequired(handle.asRaw(), FrameworkElement.iid(),
                "Microsoft.UI.Xaml.IFrameworkElement"))
        try {
            return Some((fe.ActualWidth, fe.ActualHeight))
        } finally {
            fe.close()
        }
    } catch (_: Exception) {
        return None
    }
}

// Start `animRaw` (a leaf key-frame animation) on `compObj` for the named
// property, viewing the animation identity as the CompositionAnimation base.
func startAnimation(compObj: CompositionObject, propertyName: String, animRaw: CPointer<Unit>): Unit {
    let anim = CompositionAnimation.viewOf(animRaw)
    let propHs = HString(propertyName)
    try {
        compObj.StartAnimation(propHs, anim)
    } finally {
        propHs.close()
    }
}

func stopAnimation(compObj: CompositionObject, propertyName: String): Unit {
    let propHs = HString(propertyName)
    try {
        compObj.StopAnimation(propHs)
    } finally {
        propHs.close()
    }
}
