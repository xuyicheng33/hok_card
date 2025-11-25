extends TextureButton
class_name PixelPerfectButton

## 像素精确点击的TextureButton
## 只有点击非透明区域才会响应

var _image: Image = null

func _ready():
	# 加载纹理的图片数据用于检测透明度
	if texture_normal:
		_image = texture_normal.get_image()

func _has_point(point: Vector2) -> bool:
	if not _image:
		# 没有图片时，检查是否在纹理范围内
		if texture_normal:
			var tex_size = texture_normal.get_size()
			return point.x >= 0 and point.x < tex_size.x and point.y >= 0 and point.y < tex_size.y
		return false
	
	# 将点击坐标转换为图片坐标
	var img_x = int(point.x)
	var img_y = int(point.y)
	
	# 检查是否在图片范围内
	if img_x < 0 or img_x >= _image.get_width():
		return false
	if img_y < 0 or img_y >= _image.get_height():
		return false
	
	# 获取像素颜色，检查透明度
	var pixel = _image.get_pixel(img_x, img_y)
	return pixel.a > 0.1  # alpha大于0.1才算点击到
