### 
#	Image editor module, the image viewing / editing interface.
###
imageEditor = (pasteboard) ->
	MAX_WIDTH_RATIO = 0.8
	MAX_HEIGHT_RATIO = 0.8
	SCROLL_SPEED = 25
	TEMPLATE_URL = "jstemplates/imageeditor.tmpl"

	image = null
	isScrollDragging = false
	isCropDragging = false
	dragDirection = null
	selectionScrollInterval = null
	cropIntentTimeout = null

	scrollable =
		x: false
		y: false
	dragOffset =
		x: 0
		y: 0
	imagePosition = 
		x: 0
		y: 0
	mousePosition =
		x: 0
		y: 0

	# The crop selection that appears when the user mouse drags on the image
	cropSelection = (() ->
		x = 0
		y = 0
		width = 0
		height = 0
		style = null 
		element = null
		isCropped = false
		style = 
			x: x
			y: y
			width: width
			height: height

		# Sets the CSS styles from the coordinates / dimensions
		updateStyle = () ->
			style.x = x 
			style.y = y
			style.width = width
			style.height = height

			# We can't have negative dimensions, so
			# we need to invert the dimensions 
			# and set the coordinates accordingly
			if style.width < 0
				style.width *= -1
				style.x -= style.width
			if style.height < 0
				style.height *= -1
				style.y -= style.height

			# Cap values
			if style.x < 0
				style.width += style.x
				style.x = 0

			if (style.x + style.width) > image.width
				style.width = image.width - style.x

			if style.y < 0
				style.height += style.y
				style.y = 0			

			if (style.y + style.height) > image.height
				style.height = image.height - style.y

			element.css
				left: style.x
				top: style.y
				width: style.width
				height: style.height
				"background-position": "#{-style.x}px #{-style.y}px"

			# Hide the selection when it isn't wide/high enough
			if style.width < 5 or style.height < 5
				if isCropped
					$imageEditor.removeClass("cropped")
					isCropped = false
					clearTimeout(cropIntentTimeout)
					cropIntentTimeout = setTimeout(() ->
						setUploadText(isCropped)
					, 200)

			else
				unless isCropped
					$imageEditor.addClass("cropped")
					isCropped = true
					clearTimeout(cropIntentTimeout)
					cropIntentTimeout = setTimeout(() -> 
						setUploadText(isCropped)
					, 200)

		self =
			getCropCoordinates: () -> if isCropped then style else null
			init: (startX, startY) ->
				element = $image.find(".crop-selection")
				x = startX
				y = startY
				width = 0
				height = 0
				updateStyle();

			resize: (newX, newY) ->
				width = newX - x
				height = newY - y
				updateStyle()

	)()
	
	$imageEditor = null
	$imageContainer = null
	$image = null
	$scrollBar = 
		x:
			bar: null
			track: null
			handle: null
		y:
			bar: null
			track: null
			handle: null	
	
	$uploadButton = null
	$window = $(window)
	$document = $(document)

	# Add all the event listeners, use a namespace to make removing them easier		
	addEvents = () ->
		$window.on "resize.imageeditorevent", () -> 
			setPosition()
			setSize()
			scrollImage 0, 0

		$document
			.on("click.imageeditorevent", ".upload-button", uploadImage)
			.on("click.imageeditorevent", ".delete-button", hide)
			.on("mousewheel.imageeditorevent" + (if ("onmousewheel" of document) then "" else " DOMMouseScroll.imageeditorevent"), ".image-container", scrollWheelHandler)
			.on("mousedown.imageeditorevent", ".image-container .image", mouseCropHandler)
			.on("mousedown.imageeditorevent", ".image-editor .y-scroll-bar, .image-editor .x-scroll-bar", mouseScrollHandler)
			.on("mouseup.imageeditorevent", () -> 
				if isScrollDragging 
					isScrollDragging = false
				if isCropDragging
					isCropDragging = false
					clearInterval selectionScrollInterval
			)
			.on("mousemove.imageeditorevent", (e) -> 
				dragScrollHandler e if isScrollDragging
				dragCropHandler e if isCropDragging 
			)
	# Remove the events
	removeEvents = () ->
		$document.off(".imageeditorevent")
		$window.off(".imageeditorevent")

	# Cache the needed jQuery element objects for quicker access
	cacheElements = (element) ->
		$imageEditor = $(element)
		$imageContainer = $imageEditor.find(".image-container")
		$image = $imageContainer.find(".image")
		for coordinate of $scrollBar
			$scrollBar[coordinate].bar = $imageEditor.find(".#{coordinate}-scroll-bar");
			$scrollBar[coordinate].track = $scrollBar[coordinate].bar.find(".track");
			$scrollBar[coordinate].handle = $scrollBar[coordinate].track.find(".handle");

		$uploadButton = $imageEditor.find(".upload-button")
			
	# Changes the upload button text
	setUploadText = (isCropped) ->
		buttonWidth = if isCropped then 180 else 100
		return if $uploadButton.data("cropped") is isCropped
		$uploadButton.data("cropped", isCropped)
		$uploadButton.find("span")
			.stop()
			.transition({opacity: 0}, 150, () ->
				$(@)
					.text($(@).data("#{if isCropped then 'cropped' else 'regular'}-text"))
					.css("width", "#{buttonWidth-40}px")

				$uploadButton.transition({width: buttonWidth + "px"}, () ->
					$(@).find("span").stop().transition({opacity: 1}, 150)
				)
			)

	# Sets the vertical position of the image editor window
	setPosition = () ->
		y = $window.height() / 2 - $imageEditor.outerHeight() / 2
		y = 0 if $imageEditor.outerHeight() > $window.height()
		$imageEditor.css(
			"top": y
		)

	# Resizes the image editor window, adds scrollbars if needed
	setSize = () ->
		maxWidth = MAX_WIDTH_RATIO * $window.width()
		maxHeight = MAX_HEIGHT_RATIO * $window.height()

		width = Math.min maxWidth, image.width
		height = Math.min maxHeight, image.height

		
		$imageEditor
			.css(
				"width": width
				"height": height
			)

		# TODO: Make this less repetitive
		if $imageContainer.width() < image.width
			scrollable.x = true
			$imageEditor.addClass("scroll-x")
			$imageContainer.css("height", height - $scrollBar.x.bar.outerHeight())

			# Make the scroll handle represent the visible image width
			# relative to the track
			$scrollBar.x.handle
				.css("width", ($imageContainer.width() / image.width) * $scrollBar.x.track.width())
		else 
			$imageEditor.removeClass "scroll-x"
			$imageContainer.css "height", ""
			scrollable.x = false
		
		if $imageContainer.height() < image.height
			scrollable.y = true
			$imageEditor.addClass("scroll-y")
			$imageContainer.css "width", width - $scrollBar.y.bar.outerWidth()

			# Make the scroll handle represent the visible image height
			# relative to the track
			$scrollBar.y.handle
				.css("height", ($imageContainer.height() / image.height) * $scrollBar.y.track.height())
		else 
			$imageEditor.removeClass "scroll-y"
			$imageContainer.css "width", ""
			scrollable.y = false
			
	# Handles mouse scrolling (clicking and dragging)
	mouseScrollHandler = (e) ->
		return if e.button is not 0
		$target = $ e.currentTarget

		# TODO: Make this less repetitive
		if $target.hasClass("y-scroll-bar")
			if $scrollBar.y.handle.offset().top <= e.clientY <= $scrollBar.y.handle.offset().top + $scrollBar.y.handle.height()
				dragDirection = "y"
				dragOffset.y = e.clientY - $scrollBar.y.handle.offset().top
				isScrollDragging = true
			else
				# Ignore clicks on the padding
				return if e.clientY > $scrollBar.y.bar.offset().top + $scrollBar.y.bar.height()
				if e.clientY < $scrollBar.y.handle.offset().top
					scrollImage 0, SCROLL_SPEED * 4
				else
					scrollImage 0, -SCROLL_SPEED * 4

		else if $target.hasClass("x-scroll-bar")
			if $scrollBar.x.handle.offset().left <= e.clientX <= $scrollBar.x.handle.offset().left + $scrollBar.x.handle.width()
				dragDirection = "x"
				dragOffset.x = e.clientX - $scrollBar.x.handle.offset().left
				isScrollDragging = true
			else
				# Ignore clicks on the padding
				return if e.clientX > $scrollBar.x.bar.offset().left + $scrollBar.x.bar.width()
				if e.clientX < $scrollBar.x.handle.offset().left
					scrollImage SCROLL_SPEED, 0
				else
					scrollImage -SCROLL_SPEED, 0


	# Handles mouse wheel scrolling.
	# (Scrolling while holding shift scrolls the image sideways)
	scrollWheelHandler = (e) ->
		e.preventDefault()
		deltaX = e.originalEvent.wheelDeltaX or 0
		deltaY = e.originalEvent.wheelDeltaY or e.originalEvent.wheelDelta or 0
		# Firefox
		if e.type is "DOMMouseScroll"
			# Set better delta values than what firefox throws out
			direction = -e.originalEvent.detail / Math.abs(e.originalEvent.detail)
			if e.originalEvent.axis is e.originalEvent.HORIZONTAL_AXIS
				deltaX = direction * 100
			else
				deltaY = direction * 100


		if e.originalEvent.shiftKey
			deltaX ||= deltaY
			deltaY = 0

		scrollImage deltaX / 2, deltaY / 2

	# Handles dragging of the scroll bar handles
	dragScrollHandler = (e) ->
		if dragDirection is "x"
			x = ((e.clientX - dragOffset.x - $scrollBar.x.track.offset().left) / $scrollBar.x.track.width()) * image.width
			scrollImageTo(x, undefined)	
		else if dragDirection is "y"
			y = ((e.clientY - dragOffset.y - $scrollBar.y.track.offset().top) / $scrollBar.y.track.height()) * image.height
			scrollImageTo(undefined, y)				

	# Scrolls the image by the given number of pixels
	scrollImage = (x, y) ->
		x = 0 unless scrollable.x
		y = 0 unless scrollable.y
		
		newX = -(imagePosition.x + x)
		newY = -(imagePosition.y + y)

		scrollImageTo(newX, newY)

	# Scrolls the image to the given coordinates
	scrollImageTo = (x, y) ->
		x = -imagePosition.x if x is undefined
		y = -imagePosition.y if y is undefined

		# Cap values
		x = Math.max 0, Math.min x, $image.width() - $imageContainer.width()
		y = Math.max 0, Math.min y, $image.height() - $imageContainer.height()

		# Round values
		x = Math.round x
		y = Math.round y

		imagePosition.x = -x
		imagePosition.y = -y

		# Use 3D transforms for GPU acceleration
		$image.css "transform", "translate3d(#{-x}px, #{-y}px, 0)"

		# Set the handle positions
		val = Math.round((y / ($image.height() - $imageContainer.height())) * ($scrollBar.y.track.height() - $scrollBar.y.handle.height() ))
		$scrollBar.y.handle.css "transform", "translate3d(0, #{val}px, 0)"
		val = Math.round((x / ($image.width() - $imageContainer.width())) * ($scrollBar.x.track.width() - $scrollBar.x.handle.width() ))
		$scrollBar.x.handle.css "transform", "translate3d(#{val}px, 0, 0)"

	# Handle cropping (click)
	# Sets the crop selection starting position
	mouseCropHandler = (e) ->
		isCropDragging = true
		cropSelection.init e.clientX - $image.offset().left, e.clientY - $image.offset().top
		
		mousePosition.x = e.clientX
		mousePosition.y = e.clientY
		selectionScrollInterval = setInterval selectionDragScroll, 1000 / 60

	# Handle cropping (drag)
	dragCropHandler = (e) ->
		mousePosition.x = e.clientX
		mousePosition.y = e.clientY
		cropSelection.resize e.clientX - $image.offset().left, e.clientY - $image.offset().top

	# Scrolls the image if the user is dragging 
	# the selection outside the image container area
	selectionDragScroll = () ->
		scrollDir =
			x: 0
			y: 0

		if mousePosition.x < $imageContainer.offset().left
			scrollDir.x = 1 * scrollSpeedAdjustion($imageContainer.offset().left - mousePosition.x)
		else if mousePosition.x > $imageContainer.offset().left + $imageContainer.width()
			scrollDir.x = -1 * scrollSpeedAdjustion(mousePosition.x - $imageContainer.offset().left - $imageContainer.width())

		if mousePosition.y < $imageContainer.offset().top
			scrollDir.y = 1 * scrollSpeedAdjustion($imageContainer.offset().top - mousePosition.y)
		else if mousePosition.y > $imageContainer.offset().top + $imageContainer.height()
			scrollDir.y = -1 * scrollSpeedAdjustion(mousePosition.y - $imageContainer.offset().top - $imageContainer.height())

		scrollImage SCROLL_SPEED * scrollDir.x, SCROLL_SPEED * scrollDir.y
		cropSelection.resize mousePosition.x - $image.offset().left, mousePosition.y - $image.offset().top

	# Returns a ratio for adjusting the scrollspeed
	# when dragging the selection outside of the container
	scrollSpeedAdjustion = (distance) ->
		if 0 < distance < 10
			return 0.1
		if distance < 100
			return distance / 100
		
		return 1.0

	# Loads an image and sets up the editor
	loadImage = (img) ->
		image = new Image()
		image.src = img
		image.onload = () ->
			pasteboard.template.compile(
				"jstemplates/imageeditor.tmpl",
				{ url: img },
				(compiledTemplate) ->
					cacheElements compiledTemplate
					
					$imageEditor.appendTo "body"
					$image.css
						"width": image.width
						"height": image.height
					

					setSize()
					setPosition()
			)
			

	# Uploads the image
	uploadImage = () ->
		pasteboard.fileHandler.uploadFile cropSelection.getCropCoordinates()
		# Prevent multiple uploads
		$document.off "click", ".upload-button", uploadImage

	# Hides the image editor and cleans up
	hide = () ->
		# Let the server know that the preuploaded image can be removed
		$.post("/clearfile", 
			id: pasteboard.socketConnection.getID()
		);
		# Abort any ongoing preupload
		pasteboard.fileHandler.abortPreupload()

		removeEvents()

		# Set up the "splash screen"
		$(".splash").show()
		$imageEditor.transition(
			opacity: 0
			scale: 0.95
		, 500, () ->
			pasteboard.dragAndDrop.init()
			pasteboard.copyAndPaste.init()
			$imageEditor.remove()
		)


	self = 
		# Initializes the image editor.
		# Loads and displays the given image
		init: (img) ->
			# Start loading the template
			pasteboard.template.load(TEMPLATE_URL)
			loadImage img

			# Reset values
			isScrollDragging = false
			scrollable.x = false
			scrollable.y = false
			dragOffset.x = 0
			dragOffset.y = 0
			imagePosition.x = 0
			imagePosition.y = 0

			pasteboard.dragAndDrop.hide()
			pasteboard.copyAndPaste.hide()
			$(".splash").hide()

			addEvents()

		getImage: () -> return image
			
window.moduleLoader.addModule "imageEditor", imageEditor
