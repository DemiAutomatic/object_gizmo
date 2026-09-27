export interface Vec3 {
	x: number
	y: number
	z: number
}

export interface GtaTransform {
	position: Vec3
	rotation: Vec3
	scale: Vec3
}

const DEG = 180 / Math.PI
const RAD = Math.PI / 180

export function gtaToThree(vec: Vec3): Vec3 {
	return { x: vec.x, y: vec.z, z: -vec.y }
}

export function threeToGta(vec: Vec3): Vec3 {
	return { x: vec.x, y: -vec.z, z: vec.y }
}

export function gtaRotationToEuler(rotation: Vec3): [number, number, number] {
	return [rotation.x * RAD, rotation.z * RAD, rotation.y * RAD]
}

export function eulerToGtaRotation(x: number, y: number, z: number): Vec3 {
	return {
		x: x * DEG,
		y: z * DEG,
		z: y * DEG,
	}
}
