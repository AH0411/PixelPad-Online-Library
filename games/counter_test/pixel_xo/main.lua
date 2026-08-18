-- =========================================================
-- Pixel XO v1.0.0
-- First PixelPad internet-installed local multiplayer game
--
-- HOST  = X
-- GUEST = O
--
-- Host is authoritative.
-- Guest sends MOVE requests.
-- Host broadcasts the complete board state.
-- =========================================================

local board = {
    ".", ".", ".",
    ".", ".", ".",
    ".", ".", "."
}

local cursor = 1

local role = "none"
local myMark = "?"
local turn = "X"
local result = "N"

local initialStateSent = false
local waitingForState = true

local prevUp = false
local prevDown = false
local prevLeft = false
local prevRight = false
local prevA = false

local needsRedraw = true


-- =========================================================
-- Helpers
-- =========================================================

local function pressed(now, previous)
    return now and not previous
end


local function boardString()
    return table.concat(board, "")
end


local function resetBoard()
    board = {
        ".", ".", ".",
        ".", ".", ".",
        ".", ".", "."
    }

    cursor = 1
    turn = "X"
    result = "N"

    waitingForState = false
    needsRedraw = true
end


local function sendState()
    PixelPad.netSend(
        "STATE|" ..
        boardString() ..
        "|" ..
        turn ..
        "|" ..
        result
    )
end


local function winnerFor(mark)
    local wins = {
        {1,2,3},
        {4,5,6},
        {7,8,9},

        {1,4,7},
        {2,5,8},
        {3,6,9},

        {1,5,9},
        {3,5,7}
    }

    for i = 1, #wins do
        local a = wins[i][1]
        local b = wins[i][2]
        local c = wins[i][3]

        if
            board[a] == mark and
            board[b] == mark and
            board[c] == mark
        then
            return true
        end
    end

    return false
end


local function boardFull()
    for i = 1, 9 do
        if board[i] == "." then
            return false
        end
    end

    return true
end


local function updateResult()
    if winnerFor("X") then
        result = "X"
        return
    end

    if winnerFor("O") then
        result = "O"
        return
    end

    if boardFull() then
        result = "D"
        return
    end

    result = "N"
end


local function applyHostMove(cell, mark)
    if result ~= "N" then
        return false
    end

    if turn ~= mark then
        return false
    end

    if
        cell < 1 or
        cell > 9 or
        board[cell] ~= "."
    then
        return false
    end

    board[cell] = mark

    updateResult()

    if result == "N" then
        if mark == "X" then
            turn = "O"
        else
            turn = "X"
        end
    end

    sendState()

    needsRedraw = true

    return true
end


local function parseState(message)
    local payload =
        string.sub(
            message,
            7
        )

    local first =
        string.find(
            payload,
            "|",
            1,
            true
        )

    if not first then
        return
    end

    local second =
        string.find(
            payload,
            "|",
            first + 1,
            true
        )

    if not second then
        return
    end

    local encoded =
        string.sub(
            payload,
            1,
            first - 1
        )

    local incomingTurn =
        string.sub(
            payload,
            first + 1,
            second - 1
        )

    local incomingResult =
        string.sub(
            payload,
            second + 1
        )

    if #encoded ~= 9 then
        return
    end

    for i = 1, 9 do
        board[i] =
            string.sub(
                encoded,
                i,
                i
            )
    end

    turn = incomingTurn
    result = incomingResult

    waitingForState = false

    needsRedraw = true
end


local function processNetwork()
    local message =
        PixelPad.netReceive()

    while message do
        if role == "host" then
            if
                string.sub(
                    message,
                    1,
                    5
                ) ==
                "MOVE|"
            then
                local cell =
                    tonumber(
                        string.sub(
                            message,
                            6
                        )
                    )

                if cell then
                    applyHostMove(
                        cell,
                        "O"
                    )
                end
            end
        end

        if role == "guest" then
            if
                string.sub(
                    message,
                    1,
                    6
                ) ==
                "STATE|"
            then
                parseState(
                    message
                )
            end
        end

        message =
            PixelPad.netReceive()
    end
end


local function moveCursor(dx, dy)
    local row =
        math.floor(
            (cursor - 1) / 3
        )

    local col =
        (cursor - 1) % 3

    row =
        (row + dy + 3) % 3

    col =
        (col + dx + 3) % 3

    cursor =
        row * 3 +
        col +
        1

    needsRedraw = true
end


local function attemptMove()
    if
        not PixelPad.netConnected() or
        result ~= "N" or
        turn ~= myMark or
        board[cursor] ~= "."
    then
        return
    end

    if role == "host" then
        applyHostMove(
            cursor,
            "X"
        )
    elseif role == "guest" then
        PixelPad.netSend(
            "MOVE|" ..
            tostring(cursor)
        )
    end
end


-- =========================================================
-- Drawing
-- =========================================================

local BOARD_X = 43
local BOARD_Y = 30
local CELL = 27


local function drawMark(index, x, y)
    local mark =
        board[index]

    if mark == "X" then
        PixelPad.drawLine(
            x + 6,
            y + 6,
            x + CELL - 7,
            y + CELL - 7,
            PixelPad.CYAN
        )

        PixelPad.drawLine(
            x + CELL - 7,
            y + 6,
            x + 6,
            y + CELL - 7,
            PixelPad.CYAN
        )
    elseif mark == "O" then
        PixelPad.drawCircle(
            x + 13,
            y + 13,
            8,
            PixelPad.YELLOW
        )
    end
end


local function statusText()
    if not PixelPad.netConnected() then
        return "WAITING FOR PEER"
    end

    if result == "X" then
        if myMark == "X" then
            return "YOU WIN!"
        else
            return "YOU LOSE"
        end
    end

    if result == "O" then
        if myMark == "O" then
            return "YOU WIN!"
        else
            return "YOU LOSE"
        end
    end

    if result == "D" then
        return "DRAW"
    end

    if turn == myMark then
        return "YOUR TURN"
    end

    return "OPPONENT TURN"
end


local function drawGame()
    PixelPad.clear(
        PixelPad.BLACK
    )

    PixelPad.text(
        5,
        5,
        "PIXEL XO",
        PixelPad.CYAN,
        1
    )

    local roleText =
        "NO SESSION"

    if role == "host" then
        roleText =
            "HOST / X"
    elseif role == "guest" then
        roleText =
            "GUEST / O"
    end

    PixelPad.text(
        101,
        5,
        roleText,
        PixelPad.WHITE,
        1
    )

    PixelPad.text(
        5,
        17,
        statusText(),
        result == "N"
            and PixelPad.WHITE
            or PixelPad.YELLOW,
        1
    )


    -- Grid
    PixelPad.drawLine(
        BOARD_X + CELL,
        BOARD_Y,
        BOARD_X + CELL,
        BOARD_Y + CELL * 3,
        PixelPad.WHITE
    )

    PixelPad.drawLine(
        BOARD_X + CELL * 2,
        BOARD_Y,
        BOARD_X + CELL * 2,
        BOARD_Y + CELL * 3,
        PixelPad.WHITE
    )

    PixelPad.drawLine(
        BOARD_X,
        BOARD_Y + CELL,
        BOARD_X + CELL * 3,
        BOARD_Y + CELL,
        PixelPad.WHITE
    )

    PixelPad.drawLine(
        BOARD_X,
        BOARD_Y + CELL * 2,
        BOARD_X + CELL * 3,
        BOARD_Y + CELL * 2,
        PixelPad.WHITE
    )


    for i = 1, 9 do
        local row =
            math.floor(
                (i - 1) / 3
            )

        local col =
            (i - 1) % 3

        local x =
            BOARD_X +
            col * CELL

        local y =
            BOARD_Y +
            row * CELL

        drawMark(
            i,
            x,
            y
        )
    end


    -- Cursor
    local cursorRow =
        math.floor(
            (cursor - 1) / 3
        )

    local cursorCol =
        (cursor - 1) % 3

    PixelPad.drawRect(
        BOARD_X +
            cursorCol * CELL +
            2,
        BOARD_Y +
            cursorRow * CELL +
            2,
        CELL - 4,
        CELL - 4,
        turn == myMark
            and PixelPad.GREEN
            or PixelPad.GRAY
    )


    if result ~= "N" then
        if role == "host" then
            PixelPad.text(
                18,
                116,
                "HOST: A = NEW GAME",
                PixelPad.CYAN,
                1
            )
        else
            PixelPad.text(
                22,
                116,
                "WAIT FOR HOST RESTART",
                PixelPad.GRAY,
                1
            )
        end
    else
        PixelPad.text(
            8,
            116,
            "MOVE + A    A+B HOLD = PAUSE",
            PixelPad.GRAY,
            1
        )
    end
end


-- =========================================================
-- Runtime
-- =========================================================

function start()
    role =
        PixelPad.netRole()

    if role == "host" then
        myMark = "X"
        resetBoard()

        initialStateSent =
            false
    elseif role == "guest" then
        myMark = "O"

        waitingForState =
            true
    end

    needsRedraw = true
end


function update()
    role =
        PixelPad.netRole()

    processNetwork()


    if
        role == "host" and
        PixelPad.netConnected() and
        not initialStateSent
    then
        sendState()

        initialStateSent =
            true
    end


    local upNow =
        PixelPad.joyUp() or
        PixelPad.btnForward()

    local downNow =
        PixelPad.joyDown() or
        PixelPad.btnReverse()

    local leftNow =
        PixelPad.joyLeft() or
        PixelPad.btnLeft()

    local rightNow =
        PixelPad.joyRight() or
        PixelPad.btnRight()

    local aNow =
        PixelPad.btnA()


    if pressed(
        upNow,
        prevUp
    ) then
        moveCursor(
            0,
            -1
        )
    end


    if pressed(
        downNow,
        prevDown
    ) then
        moveCursor(
            0,
            1
        )
    end


    if pressed(
        leftNow,
        prevLeft
    ) then
        moveCursor(
            -1,
            0
        )
    end


    if pressed(
        rightNow,
        prevRight
    ) then
        moveCursor(
            1,
            0
        )
    end


    if pressed(
        aNow,
        prevA
    ) then
        if
            result ~= "N" and
            role == "host" and
            PixelPad.netConnected()
        then
            resetBoard()
            sendState()
        else
            attemptMove()
        end
    end


    prevUp = upNow
    prevDown = downNow
    prevLeft = leftNow
    prevRight = rightNow
    prevA = aNow
end


function draw()
    if not needsRedraw then
        return
    end

    drawGame()

    needsRedraw = false
end


function redraw()
    drawGame()

    needsRedraw = false
end
