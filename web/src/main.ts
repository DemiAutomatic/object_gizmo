import * as THREE from 'three'
import { TransformControls } from 'three/examples/jsm/controls/TransformControls.js'
import {
	eulerToGtaRotation,
	gtaRotationToEuler,
	gtaToThree,
	threeToGta,
	type GtaTransform,
	type Vec3,
} from './space'

type Mode = 'translate' | 'rotate' | 'scale'
type Space = 'world' | 'local'
type CameraMode = 'gameplay' | 'orbit'

interface Axes {
	x?: boolean
	y?: boolean
	z?: boolean
}

interface EntityMessage extends GtaTransform {
	handle: number
	mode?: Mode
	space?: Space
	translationSnap?: number
	rotationSnap?: number
	scaleSnap?: number
	size?: number
	axes?: Axes
	cursor?: boolean
	camera?: CameraMode
}

interface CameraMessage {
	position: Vec3
	forward: Vec3
	fov: number
}

interface ConfigureMessage {
	mode?: Mode
	space?: Space
	translationSnap?: number
	rotationSnap?: number
	scaleSnap?: number
	size?: number
	axes?: Axes
	cursor?: boolean
	camera?: CameraMode
}

const browser = !(window as unknown as { invokeNative?: unknown }).invokeNative

const root = document.getElementById('app')
if (!root) throw new Error('missing #app')

const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true })
renderer.setClearColor(0x000000, 0)
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
renderer.setSize(window.innerWidth, window.innerHeight)
root.appendChild(renderer.domElement)

const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.01, 2000)
const mesh = new THREE.Object3D()
const controls = new TransformControls(camera, renderer.domElement)
const camWorld = new THREE.Vector3()
const worldPosition = new THREE.Vector3()
const worldQuaternion = new THREE.Quaternion()
const worldScale = new THREE.Vector3(1, 1, 1)
const lookTarget = new THREE.Vector3()

scene.add(mesh)
scene.add(controls)
controls.attach(mesh)

let active = false
let applying = false
let cameraReady = false
let cameraMode: CameraMode = 'gameplay'
let cursorEnabled = true

function snapValue(value: number | undefined): number | null {
	if (!value || value <= 0) return null
	return value
}

function applyAxes(axes: Axes | undefined) {
	controls.showX = axes?.x !== false
	controls.showY = axes?.z !== false
	controls.showZ = axes?.y !== false
}

function applyScaleForMode() {
	if (controls.mode === 'scale') {
		mesh.scale.copy(worldScale)
		return
	}
	mesh.scale.set(1, 1, 1)
}

function placeMesh() {
	mesh.position.copy(worldPosition).sub(camWorld)
	mesh.quaternion.copy(worldQuaternion)
	applyScaleForMode()
}

function writeEntity(data: { position: Vec3, rotation: Vec3, scale?: Vec3 }) {
	const position = gtaToThree(data.position)
	const euler = gtaRotationToEuler(data.rotation)
	worldPosition.set(position.x, position.y, position.z)
	worldQuaternion.setFromEuler(new THREE.Euler(euler[0], euler[1], euler[2], 'YZX'))
	if (data.scale) worldScale.set(data.scale.x, data.scale.y, data.scale.z)
	placeMesh()
}

function readEntity(): GtaTransform {
	const euler = new THREE.Euler().setFromQuaternion(worldQuaternion, 'YZX')
	return {
		position: threeToGta({ x: worldPosition.x, y: worldPosition.y, z: worldPosition.z }),
		rotation: eulerToGtaRotation(euler.x, euler.y, euler.z),
		scale: { x: worldScale.x, y: worldScale.y, z: worldScale.z },
	}
}

function configure(data: ConfigureMessage) {
	if (data.mode) controls.setMode(data.mode)
	if (data.space) controls.setSpace(data.space === 'local' ? 'local' : 'world')
	if (data.translationSnap !== undefined) controls.setTranslationSnap(snapValue(data.translationSnap))
	if (data.rotationSnap !== undefined) {
		controls.setRotationSnap(data.rotationSnap > 0 ? THREE.MathUtils.degToRad(data.rotationSnap) : null)
	}
	if (data.scaleSnap !== undefined) controls.setScaleSnap(snapValue(data.scaleSnap))
	if (data.size) controls.setSize(data.size)
	if (data.axes) applyAxes(data.axes)
	if (data.cursor !== undefined) {
		cursorEnabled = data.cursor
		controls.enabled = data.cursor
	}
	if (data.camera) cameraMode = data.camera
	applyScaleForMode()
}

async function fetchNui<T>(eventName: string, data?: unknown): Promise<T | null> {
	if (browser) return null
	const resource = (window as unknown as { GetParentResourceName?: () => string }).GetParentResourceName?.() ?? 'object_gizmo'
	const response = await fetch(`https://${resource}/${eventName}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(data ?? {}),
	})
	return response.json() as Promise<T>
}

function setActive(next: boolean) {
	active = next
	root!.style.display = next ? 'block' : 'none'
	renderer.domElement.style.pointerEvents = next ? 'auto' : 'none'
	if (next) {
		if (!browser) renderer.setAnimationLoop(render)
		return
	}
	renderer.setAnimationLoop(null)
	cameraReady = false
	controls.detach()
}

function render() {
	if (!active || !cameraReady) return
	renderer.render(scene, camera)
}

function open(data: EntityMessage) {
	pressedWhileActive.clear()
	applying = true
	controls.attach(mesh)
	writeEntity(data)
	configure(data)
	cameraReady = browser
	setActive(true)
	applying = false
}

function close() {
	pressedWhileActive.clear()
	setActive(false)
}

function onCamera(data: CameraMessage) {
	const nextCam = gtaToThree(data.position)
	const next = new THREE.Vector3(nextCam.x, nextCam.y, nextCam.z)
	const forward = gtaToThree(data.forward)

	if (controls.dragging) {
		worldPosition.copy(mesh.position).add(camWorld)
		worldQuaternion.copy(mesh.quaternion)
		if (controls.mode === 'scale') worldScale.copy(mesh.scale)
		const moved = camWorld.distanceToSquared(next) > 0.000001
		camWorld.copy(next)
		if (moved) mesh.position.copy(worldPosition).sub(camWorld)
	} else {
		camWorld.copy(next)
		mesh.position.copy(worldPosition).sub(camWorld)
		mesh.quaternion.copy(worldQuaternion)
		applyScaleForMode()
	}

	camera.position.set(0, 0, 0)
	camera.up.set(0, 1, 0)
	lookTarget.set(forward.x, forward.y, forward.z)
	if (lookTarget.lengthSq() < 0.0001) lookTarget.set(0, 0, -1)
	camera.lookAt(lookTarget)
	camera.fov = data.fov || 50
	camera.aspect = window.innerWidth / Math.max(1, window.innerHeight)
	camera.updateProjectionMatrix()
	cameraReady = true
}

controls.addEventListener('dragging-changed', (event: { value?: boolean }) => {
	void fetchNui('setDragging', { dragging: Boolean(event.value) })
})

controls.addEventListener('objectChange', () => {
	if (applying || !active) return
	worldPosition.copy(mesh.position).add(camWorld)
	worldQuaternion.copy(mesh.quaternion)
	if (controls.mode === 'scale') worldScale.copy(mesh.scale)

	const entity = readEntity()
	void fetchNui<{ clamped?: boolean, position?: Vec3, rotation?: Vec3 }>('moveEntity', {
		handle: currentHandle,
		position: entity.position,
		rotation: entity.rotation,
		scale: entity.scale,
	}).then((response) => {
		if (!response?.clamped || !response.position || !response.rotation) return
		applying = true
		writeEntity({ position: response.position, rotation: response.rotation, scale: { x: worldScale.x, y: worldScale.y, z: worldScale.z } })
		applying = false
	}).catch(() => {})
})

let currentHandle = 0

let pointerDown = false
window.addEventListener('pointerdown', () => {
	pointerDown = true
})
window.addEventListener('pointerup', () => {
	pointerDown = false
})
window.addEventListener('pointermove', (event) => {
	if (!active || !pointerDown || controls.dragging || cameraMode !== 'orbit' || !cursorEnabled) return
	void fetchNui('rotateCamera', { x: event.movementX, y: event.movementY })
})
window.addEventListener('wheel', (event) => {
	if (!active || cameraMode !== 'orbit') return
	void fetchNui('zoomCamera', { delta: event.deltaY })
}, { passive: true })

const FORWARDED_KEYS = new Set([
	'KeyW', 'KeyR', 'KeyS', 'KeyQ', 'KeyG', 'KeyX', 'KeyC', 'Enter', 'NumpadEnter', 'Escape', 'AltLeft',
])
const pressedWhileActive = new Set<string>()

window.addEventListener('keydown', (event) => {
	if (!active) return
	if (FORWARDED_KEYS.has(event.code)) pressedWhileActive.add(event.code)
	if (event.code === 'AltLeft' || event.code === 'Escape' || event.code === 'Tab') {
		event.preventDefault()
	}
})

window.addEventListener('keyup', (event) => {
	if (!active || !FORWARDED_KEYS.has(event.code)) return
	const startedHere = pressedWhileActive.delete(event.code)
	event.preventDefault()
	if (!startedHere) return
	void fetchNui('key', { code: event.code })
})

window.addEventListener('resize', () => {
	renderer.setSize(window.innerWidth, window.innerHeight)
	camera.aspect = window.innerWidth / Math.max(1, window.innerHeight)
	camera.updateProjectionMatrix()
})

window.addEventListener('message', (event: MessageEvent<{ action?: string, data?: unknown }>) => {
	const action = event.data?.action
	const data = event.data?.data
	if (action === 'open') {
		const entity = data as EntityMessage
		currentHandle = entity.handle
		open(entity)
	} else if (action === 'close') {
		currentHandle = 0
		close()
	} else if (action === 'setEntity' && data) {
		applying = true
		writeEntity(data as EntityMessage)
		applying = false
	} else if (action === 'setCamera' && data) {
		onCamera(data as CameraMessage)
	} else if (action === 'configure' && data) {
		configure(data as ConfigureMessage)
	}
})

setActive(false)

function setupBrowserMode() {
	const box = new THREE.Mesh(
		new THREE.BoxGeometry(1, 1, 1),
		new THREE.MeshStandardMaterial({ color: 0x31a4fc, roughness: 0.6 })
	)
	scene.add(box)
	scene.add(new THREE.AmbientLight(0xffffff, 0.7))
	const sun = new THREE.DirectionalLight(0xffffff, 1.2)
	sun.position.set(4, 8, 2)
	scene.add(sun)
	document.body.style.background = '#111'

	let theta = 0.8
	let phi = 1.1
	let radius = 6
	let draggingView = false

	open({
		handle: 1,
		position: { x: 0, y: 0, z: 0 },
		rotation: { x: 0, y: 0, z: 0 },
		scale: { x: 1, y: 1, z: 1 },
		mode: 'translate',
		space: 'world',
		size: 0.8,
		camera: 'gameplay',
		cursor: true,
	})

	window.addEventListener('pointerdown', (event) => {
		if (event.button === 0) draggingView = !controls.dragging
	})
	window.addEventListener('pointerup', () => {
		draggingView = false
	})
	window.addEventListener('pointermove', (event) => {
		if (!draggingView || controls.dragging) return
		theta -= event.movementX * 0.005
		phi = Math.min(Math.PI - 0.12, Math.max(0.12, phi - event.movementY * 0.005))
	})
	window.addEventListener('wheel', (event) => {
		radius = Math.min(20, Math.max(2, radius + Math.sign(event.deltaY) * 0.4))
	}, { passive: true })

	window.addEventListener('keyup', (event) => {
		if (event.code === 'KeyR') controls.setMode('rotate')
		if (event.code === 'KeyW') controls.setMode('translate')
		if (event.code === 'KeyQ') controls.setSpace(controls.space === 'local' ? 'world' : 'local')
	})

	function browserFrame() {
		const sinPhi = Math.sin(phi)
		camera.position.set(
			radius * sinPhi * Math.cos(theta),
			radius * Math.cos(phi),
			radius * sinPhi * Math.sin(theta)
		)
		camera.lookAt(mesh.position)
		cameraReady = true
		renderer.render(scene, camera)
		requestAnimationFrame(browserFrame)
	}

	browserFrame()
}

if (browser) setupBrowserMode()
