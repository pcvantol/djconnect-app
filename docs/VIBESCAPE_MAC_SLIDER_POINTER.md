# VibeScape Mac slider pointer position

Owner report: clicking the vertical dynamics slider does not move its value to the pointer position. The Mac renderer used a horizontal SwiftUI Slider rotated by minus90degrees.

The Mac path now uses a native vertical NSSlider with the existing0...1 binding to VisualDirectorVisit.setDynamics. It retains white track tint, the glass container, reset/follow behavior, accessibility label/identifier and the existing hover/auto-hide areas. Native cell tracking provides click-to-position and dragging. The subclass brackets actual mouse tracking with editingChanged true/false, keeping controls visible while dragging. iOS keeps its existing slider.

The native regression mounts the actual representable in an AppKit window and drives NSSliderCell tracking at80percent and20percent of the visible track, then checks the resulting SwiftUI value binding. It uses the native view's flipped coordinate convention. The initial mouseDown/mouseUp modal-loop probe exited without a completed test result (not counted as PASS); the first cell-tracking assertions then failed because the harness assumed an unflipped view. Corrected native coordinates are verified in the final run. Physical Mac mouse/drag/auto-hide acceptance remains separate.

Validation: corrected native cell-tracking/binding testPASS; signed macOS/iOS40442 builds and strict signaturesPASS. Installation/readback follows separately.
