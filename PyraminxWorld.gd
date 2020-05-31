extends Spatial

#Change this value for more complicated pyraminx
const pyraminxDimention:int = 5

onready var pyraminx = preload("res://pyraminx_object.tscn")
# all pyraminx by their names are here
var pyraminxMap:Dictionary = {}

const PI2:float = PI/2
const doublePI:float = 2*PI
const RAY_LENGTH:int = 4
const v0:Vector3 = Vector3(0,0,0)
const PI3_values = [0, 2*PI/3.0, 4*PI/3.0, 2*PI]

# vectors for pyraminx
var zv = Vector3(0,-1.417,-1).normalized()
var xv = zv.rotated(Vector3(0,1,0),doublePI/3)
var yv = zv.rotated(Vector3(0,1,0),-doublePI/3)
var xy = yv - xv
var yz = zv - yv
var xz = zv - xv
var xyn = (xv.cross(yv)).normalized()
var yzn = (yv.cross(zv)).normalized()
var zxn = (zv.cross(xv)).normalized()
var ynn = Vector3(0,1,0)
var faceToAxis:Array = [ynn,yzn,zxn,xyn]


# mouse and modes
var last_mouse_position:Vector2 = Vector2()
var inRotationMode:bool = false
var inManipulationMode:bool = false
var postAnimationMode:bool = false

#Camera
var cameraPosition:Transform
var cameraRotationTheta:float = 0
var cameraRotationPhi:float = 0

#rotation objects
var manipulationInitialized:bool = false
var manipulationObjectIx:Quat = Quat()
var manipulationNormal:Vector3 = Vector3()
var manipulationRotation:float = 0.0
var manipulationAxisIx:int = 0
var manipulationOrientation:bool = true #true-up, false-down
var manipulationPyraminx:Array = []
var manipulationPyraminxTransform:Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	cameraPosition = $CameraHub.transform
	updateCamera($CameraHub)
	$main/pyraminx_object.visible = false
	$main.remove_child($main/pyraminx_object)
	
	var N = pyraminxDimention-1
	createSide($main, v0,   xv, yv, pyraminxDimention, pyraminxMap, Quat(1,0,0,0), Quat(0,1,0,0), Quat(0,0,1,0))
	createSide($main, v0,   zv, yv, pyraminxDimention, pyraminxMap, Quat(1,0,0,0), Quat(0,0,0,1), Quat(0,0,1,0))
	createSide($main, v0,   xv, zv, pyraminxDimention, pyraminxMap, Quat(1,0,0,0), Quat(0,1,0,0), Quat(0,0,0,1))
	createSide($main, N*xv, xz, xy, pyraminxDimention, pyraminxMap, Quat(0,1,0,0), Quat(0,0,0,1), Quat(0,0,1,0))

	$main.translate(Vector3(0, 0.5, 0))
	$main.scale = Vector3(1.6/pyraminxDimention, 1.6/pyraminxDimention, 1.6/pyraminxDimention)
	
	# enable draging
	set_process_unhandled_input(true)

func quatToName(q:Quat) -> String:
	return str(q.x)+"_"+str(q.y)+"_"+str(q.z)+"_"+str(q.w)

func nameToQuat(name:String):
		var tokens:PoolStringArray = name.split("_", true)
		if tokens.size() > 3 and tokens[0].is_valid_integer() :
			# and tokens[2].is_valid_integer()  and tokens[3].is_valid_integer()  and tokens[4].is_valid_integer() :
			return Quat(int(tokens[0]), int(tokens[1]), int(tokens[2]), int(tokens[3]))
		else:
			return null

func createSide(scene, origin:Vector3, v1:Vector3, v2:Vector3, n:int, pyraminx_map:Dictionary, q1:Quat, q2:Quat, q3:Quat):
	var vl:Vector3 = (v2 - v1).normalized()
	var vs:Vector3 = (v2 + v1).normalized()
	var vn:Vector3 = v1.cross(v2).normalized()
	for x in range(n):
		for y in range(x*2+1):
			var q4 = Quat(1,1,1,1)-q1-q2-q3
			var a = n-1-int((x*2-y)/2)
			var b = n-1-int(y/2)
			var q = qScale(q1,x) + qScale(q2,a) + qScale(q3,b) + qScale(q4,n-1)
			var qname = quatToName(q)
			if ((x + a + b) != (2*(n-1))) or (not pyraminx_map.has(qname)):
				var pyraminxInst = pyraminx.instance()
				var position = origin + v1*x + vl*0.5*y
				if y % 2 == 1: position = position - 0.3*vs
				pyraminxInst.translate(position)
				if y % 2 == 1: pyraminxInst.rotate(vn, PI)
				while pyraminx_map.has(qname): qname = qname+"_"
				pyraminxInst.name = qname
				pyraminx_map[qname] = pyraminxInst
				scene.add_child(pyraminxInst)

func _unhandled_input(event):
	if postAnimationMode:
		pass
	
	if event is InputEventMouseButton:
		var mouse_pressed = event.is_pressed()

		if mouse_pressed:
			last_mouse_position = event.position
			# if no colliding proper object is found
			# then go in rotation mode
			inRotationMode = true
			
			# try to check if there is collision with known object
			var clickedObject = get_object_under_mouse($CameraHub/Camera)
			var collider = clickedObject.get("collider")
			if is_instance_valid(collider):
				var colliderName = collider.get_parent().name
				# print("collider: "+str(colliderName))
				if "Shuffle" == colliderName:
					inRotationMode = false
					doShuffle()
					return
				var ObjectIx:Quat = nameToQuat(colliderName)
				if ObjectIx != null  and vectorToFace(clickedObject.normal)>-1:
					#collect pyraminx for rotation
					manipulationNormal = clickedObject.normal
					#do we have a face hit
					inRotationMode = false
					inManipulationMode = true
					manipulationInitialized = false
					manipulationObjectIx = ObjectIx 

		else:
			# when mouse is released disable modes
			if inManipulationMode:
				postAnimationMode = true
			inManipulationMode = false
			inRotationMode = false
	
	if event is InputEventMouseMotion:
		var delta = event.position - last_mouse_position
		last_mouse_position = event.position
		# in camera rotation mode
		if inRotationMode:
			cameraRotationPhi += -delta.x * 0.01
			cameraRotationTheta += -delta.y * 0.01
			if cameraRotationTheta > PI2: cameraRotationTheta = PI2
			if cameraRotationTheta < -PI2: cameraRotationTheta = -PI2
			updateCamera($CameraHub)

		if inManipulationMode:
			if not manipulationInitialized:
				if(abs(delta.x)+abs(delta.y)) < 6:
					#not enough displacement for vector to be directional
					return
				manipulationRotation = 0
				#detect rotation
				var faceIx:int = vectorToFace(manipulationNormal)
				if faceIx < 0:
					inManipulationMode = false
					return
				var horizon:Vector3 = Vector3(1,0,0).rotated(Vector3(0,1,0),$CameraHub.rotation.y)
				var up = manipulationNormal.cross(horizon).normalized()
				var dragVector = delta.y*horizon + delta.x*up
				var rotateIx = vectorToFace(dragVector)
				if rotateIx < 0 or rotateIx == faceIx:
					inManipulationMode = false
					return
				manipulationOrientation = manipulationNormal.cross(faceToAxis[rotateIx]).y < 0
				# print( "manipulationOrientation="+ str(manipulationOrientation)
				#	   + " dot="+str(manipulationNormal.cross(faceToAxis[rotateIx])))
				manipulationAxisIx = rotateIx
				updateManipulationPyraminx(manipulationObjectIx, rotateIx)
				saveManipulationPyraminxTransformations()
				manipulationInitialized = true
			else:
				# do rotation
				manipulationRotation += ((1 if manipulationOrientation else -1) 
									  * (-delta.x if manipulationAxisIx == 0 else -delta.y)
									  * 0.01)
				doRotateManipulation(manipulationAxisIx, manipulationRotation)
				pass

var targetRotation = []
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if postAnimationMode:
		if targetRotation.size() == 0:
			# not initialized
			# normalize rotation between 0 and doublePI
			manipulationRotation -= int(manipulationRotation / doublePI) * doublePI
			#normalize rotation to PI3_values index
			if manipulationRotation < 0: manipulationRotation += doublePI
			targetRotation = [roundToPI3(manipulationRotation)]
		else:
			# animate rotation to PI3 angle
			if abs(manipulationRotation - targetRotation[0]) < 0.1:
				manipulationRotation = targetRotation[0]
				doRotateManipulation(manipulationAxisIx, manipulationRotation)
				updatePyraminxAfterManipulation(manipulationAxisIx, manipulationRotation, manipulationOrientation)
				clearManipulation()
				postAnimationMode = false
			else:
				manipulationRotation += 0.1 if manipulationRotation < targetRotation[0] else -0.1
				doRotateManipulation(manipulationAxisIx, manipulationRotation)

func doRotateManipulation(axisIx: int, rotation: float):
	# rotate layer pyraminx
	var axis = faceToAxis[axisIx]
	for i in range(manipulationPyraminx.size()):
		manipulationPyraminx[i].transform = manipulationPyraminxTransform[i]
		rotateAround(manipulationPyraminx[i], axis, rotation)

func rotateAround(obj, axis: Vector3, angle: float):
	# ugly approximation for the rotation center
	var tStart = Vector3(0,-(pyraminxDimention-1.0)/pyraminxDimention +0.00347*pyraminxDimention,0)
	obj.global_translate (-tStart)
	obj.transform = obj.transform.rotated(axis, angle)
	obj.global_translate (tStart)

func updatePyraminxAfterManipulation(AxisIx: int, Rotation:float, Orientation: bool):
	# update names and indexes
	#if Axis.x <-0.9 or Axis.y <-0.9 or Axis.z <-0.9: Rotation = doublePI - Rotation
	var rotateIx = roundToPI3Ix(Rotation)
	# print("Axis: "+str(AxisIx)+" rotateIx: "+str(rotateIx)+" Orientation:"+str(Orientation))
	if rotateIx == 0 or rotateIx == 4:
		# no rotation
		return
	# axis 2 is with oposite vector - it needs to be reverted
	if AxisIx==2:
		rotateIx = 3 - rotateIx
	rotateIx %= 4
	# it looks like godot does not allow duplicate names
	# thus set temporal names berore assigning the new ones to avoid @ naming
	# manipulationPyraminx[i].name="in process"
	var manipulationSize = manipulationPyraminx.size()
	var namesByIx: Array = []
	for i in range(manipulationSize):
		namesByIx.append(manipulationPyraminx[i].name)
		manipulationPyraminx[i].name="in process"
	# generate new mapping indexes to serve as rotation
	# AxisIx will not be moved
	var ixMapping:Array = [AxisIx,AxisIx,AxisIx,AxisIx]
	ixMapping[(AxisIx+1)%4] = (AxisIx+3)%4
	ixMapping[(AxisIx+2)%4] = (AxisIx+1)%4
	ixMapping[(AxisIx+3)%4] = (AxisIx+2)%4
	# make the required rotations
	var valueIx:Array = [0,1,2,3]
	for _r in range(rotateIx):
		for i in range(4):
			valueIx[i] = ixMapping[valueIx[i]]
	#get old names and generate new names
	for i in range(manipulationSize):
		var oldName = namesByIx[i]
		var oldObjectIx:Quat=nameToQuat(oldName)
		var newObjectIx:Quat=Quat(0,0,0,0)
		for i in range(4):
			newObjectIx += qScale(intToQuat(i), ixQuat(oldObjectIx, valueIx[i]))
		var newName = quatToName(newObjectIx)
		var nameLen = len(oldName)
		while len(newName) < nameLen:
			newName = newName+"_"
		namesByIx[i] = newName
	# set new names and update map
	for i in range(manipulationSize):
		manipulationPyraminx[i].name = namesByIx[i]
		pyraminxMap[namesByIx[i]] = manipulationPyraminx[i]


func saveManipulationPyraminxTransformations():
	#store original transformations
	manipulationPyraminxTransform = []
	for i in range(manipulationPyraminx.size()):
		manipulationPyraminxTransform.append(manipulationPyraminx[i].transform)

func clearManipulation():
	targetRotation = []
	manipulationPyraminx=[]
	manipulationPyraminxTransform=[]
	manipulationInitialized = false
	manipulationRotation = 0.0

# cast a ray from camera at mouse position, and get the object colliding with the ray
func get_object_under_mouse(camera):
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_from = camera.project_ray_origin(mouse_pos)
	var ray_to = ray_from + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var space_state = get_world().direct_space_state
	var selection = space_state.intersect_ray(ray_from, ray_to)
	#print("selection: "+str(selection))
	return selection

func updateCamera(camera):
	camera.transform = cameraPosition
	camera.rotate_x(cameraRotationTheta)
	camera.rotate_y(cameraRotationPhi)

func updateManipulationPyraminx(ObjectIx: Quat, rotateIx:int):
	# collect all roratable pyraminx in array
	# print("ObjectIx "+str(ObjectIx)+" rotateIx "+str(rotateIx))
	# take all pyraminx with same ObjectIx[rotateIx]
	manipulationPyraminx=[]
	var constQ = intToQuat(rotateIx)
	var aQ = rolQuat(constQ)
	var bQ = rolQuat(aQ)
	var cQ = rolQuat(bQ)
	constQ = qScale(intToQuat(rotateIx), ixQuat(ObjectIx, rotateIx))
	
	for a in range(pyraminxDimention):
		for b in range(pyraminxDimention):
			for c in range(pyraminxDimention):
				var qt:Quat = constQ + qScale(aQ,a) + qScale(bQ,b) + qScale(cQ,c)
				var name = quatToName(qt)
				while pyraminxMap.has(name):
					manipulationPyraminx.append(pyraminxMap[name])
					name = name + "_"

func vectorToFace(n:Vector3)-> int:
	var dots = [0.9, abs(faceToAxis[0].dot(n)),abs(faceToAxis[1].dot(n)),abs(faceToAxis[2].dot(n)),abs(faceToAxis[3].dot(n))]
	var maxIx = 0
	for i in range(1,5):
		if dots[maxIx] < dots[i]:
			maxIx = i
	return maxIx-1

func doShuffle():
	randomize()
	var N = pyraminxDimention - 1 
	var actions = 20 + pyraminxDimention * randi() % 20
	for _i in range(actions):
		var axisIx:int = randi() % 4
		var a:int = randi() % pyraminxDimention
		var b:int = randi() % pyraminxDimention
		var ObjectIx: Quat = Quat(N,b,a,pyraminxDimention-a)
		for _j in range(1+(randi() % 4)):
			ObjectIx = rolQuat(ObjectIx)
		var rotation =  PI3_values[1 + randi() % 3]
		updateManipulationPyraminx(ObjectIx, axisIx)
		saveManipulationPyraminxTransformations()
		doRotateManipulation(axisIx, rotation)
		updatePyraminxAfterManipulation(axisIx, rotation, true)

func roundToPI3(rotation: float) -> float:
	return PI3_values[roundToPI3Ix(rotation)]

func getRadiantIx(angle:float) -> int:
	return int(roundToPI3(angle)/PI2)%4

func roundToPI3Ix(rotation: float) -> int:
	# normalize rotation between 0 and doublePI
	rotation -= int(rotation / doublePI) * doublePI
	#normalize rotation to PI3_values index
	if rotation < 0: rotation += doublePI
	# calculate differances
	var diffs = []
	for i in range(PI3_values.size()):
		diffs.append(abs(rotation - PI3_values[i]))
	# get the min index
	var minIx = 0
	for i in range(1, PI3_values.size()):
		if diffs[minIx] > diffs[i]:
			minIx = i
	return minIx

func qScale(q:Quat, f:float) -> Quat:
	return Quat(q.x*f, q.y*f, q.z*f, q.w*f)
	
func rolQuat(q:Quat)->Quat:
	return Quat(q.y,q.z,q.w,q.x)

func rorQuat(q:Quat)->Quat:
	return Quat(q.w,q.x,q.y,q.z)

func intToQuat(i:int)->Quat:
	if   i == 0: return Quat(1,0,0,0)
	elif i == 1: return Quat(0,1,0,0)
	elif i == 2: return Quat(0,0,1,0)
	elif i == 3: return Quat(0,0,0,1)
	else: return Quat(0,0,0,0)

func ixQuat(q:Quat, ix:int)->float:
	if   ix == 0: return q.x
	elif ix == 1: return q.y
	elif ix == 2: return q.z
	elif ix == 3: return q.w
	else: return 0.0
