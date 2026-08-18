local count = 0
local prevRight = false
local prevLeft = false
local prevA = false
local prevB = false
local needsRedraw = true

local function pressed(now, before)
    return now and not before
end

local function drawGame()
    PixelPad.clear(PixelPad.BLACK)

    PixelPad.text(31, 14, "COUNTER TEST", PixelPad.CYAN, 1)
    PixelPad.drawLine(10, 28, 150, 28, PixelPad.WHITE)

    PixelPad.text(56, 48, tostring(count), PixelPad.YELLOW, 2)

    PixelPad.text(19, 82, "RIGHT +1   LEFT -1", PixelPad.WHITE, 1)
    PixelPad.text(25, 96, "A +10     B RESET", PixelPad.WHITE, 1)
    PixelPad.text(29, 113, "A+B HOLD = PAUSE", PixelPad.CYAN, 1)
end

function start()
    count = 0
    needsRedraw = true
end

function update()
    local rightNow = PixelPad.btnRight()
    local leftNow = PixelPad.btnLeft()
    local aNow = PixelPad.btnA()
    local bNow = PixelPad.btnB()

    if pressed(rightNow, prevRight) then
        count = count + 1
        needsRedraw = true
    end

    if pressed(leftNow, prevLeft) then
        count = count - 1
        needsRedraw = true
    end

    if pressed(aNow, prevA) then
        count = count + 10
        needsRedraw = true
    end

    if pressed(bNow, prevB) then
        count = 0
        needsRedraw = true
    end

    prevRight = rightNow
    prevLeft = leftNow
    prevA = aNow
    prevB = bNow
end

function draw()
    if needsRedraw then
        drawGame()
        needsRedraw = false
    end
end

function redraw()
    drawGame()
    needsRedraw = false
end
