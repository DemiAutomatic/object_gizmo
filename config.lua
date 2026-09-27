Config = {}

-- Colour of the outline drawn around the entity being manipulated.
-- Values are RGBA, each between 0 and 255.
Config.outlineColor = {
	r = 255,
	g = 255,
	b = 255,
	a = 255
}

-- Outline shader used to render the highlight.
-- 0 = default (hard edge), 1 = softer/filled edge.
Config.outlineShader = 0

-- Peds cannot be outlined, so they are made translucent instead.
-- Alpha applied to a ped while the gizmo is active (0 - 255).
Config.pedAlpha = 200

-- Allow scaling mode ([S]).
-- Scaling does not affect collisions and resets once physics are applied.
Config.enableScale = false

-- Enable the debug tooling (the /testGizmo command).
-- Leave this off on a live server: the command lets any player spawn objects.
Config.debug = false

-- 'gameplay' keeps the player's camera. [G] releases the cursor so they can look around.
-- 'orbit' takes a scripted camera that orbits the entity while the cursor is held.
Config.camera = 'gameplay'

-- Starting transform mode: 'translate', 'rotate', or 'scale'.
Config.mode = 'translate'

-- 'world' aligns the gizmo to the world. 'local' aligns it to the entity.
Config.space = 'world'

-- Where the handles sit. 'origin' matches the entity position scripts already save.
-- 'center' uses the model bounding box, which is better for rotating props.
Config.pivot = 'origin'

-- Freeze the entity while editing, then restore the freeze state it had before.
Config.freezeEntity = true

-- Freeze the player ped for the duration of the edit.
Config.freezePlayer = false

-- Drop entity collision for the duration of the edit, then turn it back on.
Config.disableCollision = false

-- [Esc] restores the entity to the transform it had when the gizmo opened.
Config.enableCancel = true

-- Ask the network for control of the entity before editing it.
Config.requestControl = true

-- Use sleepless_prompts for the control strip when that resource is started.
-- ox_lib text UI is used when prompts are unavailable or this is false.
Config.prompts = true

-- sleepless_prompts slot. Ignored when prompts are not showing.
Config.promptPosition = 'bottom-center'

-- sleepless_prompts layout: 'row' or 'column'.
Config.promptLayout = 'row'

-- ox_lib text UI position when prompts are not showing.
Config.textUiPosition = 'right-center'

-- Live position and rotation on the ox_lib text UI.
-- The prompt strip does not repeat these numbers.
Config.showCoords = true

-- Draw the gizmo this size. Three.js screen-space scale.
Config.gizmoSize = 0.5

-- Snap is off until the player toggles it. Distances are metres. Rotation is degrees.
Config.snapEnabled = false
Config.translationSnap = 0.25
Config.rotationSnap = 15
Config.scaleSnap = 0.1

-- Show the snap toggle, the clipboard copy, and the ground snap in the control list.
Config.enableSnapToggle = true
Config.enableCopy = true
Config.snapToGround = true

-- Player movement stays off while the gizmo is open so [W] does not walk.
Config.playerCanMove = false

-- Orbit camera limits, used only when the camera mode is 'orbit'.
Config.orbit = {
	minRadius = 1.5,
	maxRadius = 25.0,
	zoomStep = 0.75,
	sensitivity = 0.005,
	blend = 250,
}
