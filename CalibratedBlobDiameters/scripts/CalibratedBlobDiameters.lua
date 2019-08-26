--[[----------------------------------------------------------------------------

  Application Name:
  CalibratedBlobDiameters
  
  Summary:
  Measuring coin diameters on calibrated and corrected image

  Description:
  Calibrating a camera using one shot of a checkerboard calibration target.
  Correcting the image by rectification with alignment of camera and world coordinates.
  Finding coins and measuring their diameters in the rectified image.

  How to Run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the image viewer on the DevicePage.
  To run this sample a device with SICK Algorithm API is necessary.
  For example InspectorP or SIM4000 with latest firmware. Alternatively the
  Emulator on AppStudio 2.3 or higher can be used. The images can be seen in the
  image viewer on the DevicePage.

  More Information:
  Tutorial "Algorithms - Calibration2D".

------------------------------------------------------------------------------]]
--Start of Global Scope---------------------------------------------------------

-- Delay in ms between visualization steps for demonstration purpose
local DELAY = 1000

-- The diameter of a 10 cent Euro coin is 19.75 mm (source: Wikipedia)
local COIN_DIAMETER = 19.75 -- in mm
local DIAMETER_TOLERANCE = 1 -- in mm

-- Creating viewer
local viewer = View.create()

-- Shape decorations for pass/fail
local passDecoration = View.PixelRegionDecoration.create()
passDecoration:setColor(0, 255, 0, 100) -- Transparent green

local failDecoration = View.PixelRegionDecoration.create()
failDecoration:setColor(255, 0, 0, 100) -- Transparent red

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

--@calibrate(checkerBoard:Image):Image
local function calibrate(checkerBoard)
  -- Specify the size of a square in the world (for example 166 mm / 11 squares)
  local squareSize = 166.0 / 11 -- mm

  -- Perform a one-shot calibration
  local cameraModel, error = Image.Calibration.Pose.estimateOneShot(checkerBoard, {squareSize}, 'COORDINATE_CODE')
  print('Camera calibrated with average error: ' .. (math.floor(error * 10)) / 10 .. ' px')

  -- Correct the image of the calibration target as a test, using "align" mode
  local correction = Image.Calibration.Correction.create()
  local cxy = squareSize * 6   -- Select center point for aligned image in both x and y
  local sxy = squareSize * 13  -- Select the size of the alignment region in both x and y
  local worldRectangle = Shape.createRectangle(Point.create(cxy, cxy), sxy, sxy)
  correction:setAlignMode(cameraModel, worldRectangle)
  local correctedImage = correction:apply(checkerBoard)
  viewer:clear()
  viewer:addImage(correctedImage)
  viewer:present()
  Script.sleep(DELAY) -- For demonstration purpose only
  return correction
end

--@measure(liveImage:Image,correction:Image.Calibration.Correction)
local function measure(liveImage, correction)

  -- Rectify the image
  local correctedImage = correction:apply(liveImage)
  viewer:clear()
  viewer:addImage(correctedImage)
  viewer:present()
  Script.sleep(DELAY) -- For demonstration purpose only

  -- Find the coins
  local darkRegions =
    correctedImage:threshold(1, 125):dilate(5):erode(5):fillHoles()
  local blobs = darkRegions:findConnected(1000)
  local coinFilter = Image.PixelRegion.Filter.create()
  coinFilter:setRange('COMPACTNESS', 0.7, 1.0)
  coinFilter:sortBy('AREA')
  local coins = coinFilter:apply(blobs, correctedImage)

  -- Measure the coin sizes
  for c = 1, #coins do
    local area = coins[c]:getArea(correctedImage)
    local center = coins[c]:getCenterOfGravity(correctedImage)
    local r = math.sqrt(area / math.pi)
    local d = 2 * r

    -- Visualize pass/fail
    if math.abs(d - COIN_DIAMETER) <= DIAMETER_TOLERANCE then
      viewer:addPixelRegion(coins[c], passDecoration)
    else
      viewer:addPixelRegion(coins[c], failDecoration)
    end

    -- Add text with the measured size
    local text = View.TextDecoration.create()
    text:setPosition(center:getX() + r, center:getY() - r)
    text:setSize(8) -- Text size in mm
    viewer:addText(string.format('d = %.1f', d), text) -- Print result with one decimal

    print('Diameter coin ' .. c .. ': ' .. string.format('d = %.2f', d))
  end

  viewer:present()
  print('App finished.')
end

local function main()
  -- Calibrate
  local checkerBoard = Image.load('resources/pose.bmp')
  viewer:clear()
  viewer:addImage(checkerBoard)
  viewer:present()
  Script.sleep(DELAY) -- For demonstration purpose only

  local correction = calibrate(checkerBoard)

  -- Calibrated measurement in simulated "live image"
  local liveImage = Image.load('resources/coins.bmp')
  viewer:clear()
  viewer:addImage(liveImage)
  viewer:present()
  Script.sleep(DELAY) -- For demonstration purpose only

  measure(liveImage, correction)
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)

--End of Function and Event Scope--------------------------------------------------