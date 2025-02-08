local constants = require('lollo_priority_signals.constants')
local logger = require('lollo_priority_signals.logger')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stringUtils = require('lollo_priority_signals.stringUtils')


local _texts = {
    goThere = _('GoThere'),
    locator = _('OpenLocator'),
    note = _('Note'),
    refresh = _('Refresh'),
    signalLocatorWindowTitle = _('SignalLocatorWindowTitle'),
    signalsOff = _('PrioritySignalsOff'),
    signalsOn = _('PrioritySignalsOn'),
    warningWindowTitle = _('WarningWindowTitle'),
}

local _windowXShift = -200
local _windowYShift = 40

local utils = {
    moveCamera = function(position123)
        -- logger.print('moveCamera starting, position123 =') logger.debugPrint(position123)
        local cameraData = game.gui.getCamera()
        game.gui.setCamera({position123[1], position123[2], cameraData[3], cameraData[4], cameraData[5]})
    end,
    modifyOnOffButtonLayout = function(layout, isOn)
        local img = nil
        if isOn then
            img = api.gui.comp.ImageView.new('ui/lollo_priority_signals/checkbox_valid.tga')
            img:setTooltip(_texts.signalsOn)
            layout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        else
            img = api.gui.comp.ImageView.new('ui/lollo_priority_signals/checkbox_invalid.tga')
            img:setTooltip(_texts.signalsOff)
            layout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        end
    end,
}
utils.getCameraController = function()
    local gameUI = api.gui.util.getGameUI()
    if not(gameUI) then return nil end

    local renderer = api.gui.comp.GameUI.getMainRendererComponent(gameUI)
    if not(renderer) then return nil end

    return api.gui.comp.RendererComponent.getCameraController(renderer)
end
utils.goToEntity = function(entityId)
    local camera = utils.getCameraController()
    if camera ~= nil and camera:getFollowEntity() ~= entityId then
        camera:follow(entityId, true)
    end
end
---position window keeping it within the screen
---@param window any
---@param initialPosition {x:number, y:number}|nil
utils.setWindowPosition = function(window, initialPosition)
    local gameContentRect = api.gui.util.getGameUI():getContentRect()
    local windowContentRect = window:getContentRect()
    local windowMinimumSize = window:calcMinimumSize()
    logger.print('### gameContentRect =') logger.debugPrint(gameContentRect)
    logger.print('### windowContentRect =') logger.debugPrint(windowContentRect)
    logger.print('### windowMinimumSize =') logger.debugPrint(windowMinimumSize)

    local windowHeight = math.max(windowContentRect.h, windowMinimumSize.h)
    local windowWidth = math.max(windowContentRect.w, windowMinimumSize.w)
    local positionX = (initialPosition ~= nil and initialPosition.x) or math.max(0, (gameContentRect.w - windowWidth) * 0.5)
    local positionY = (initialPosition ~= nil and initialPosition.y) or math.max(0, (gameContentRect.h - windowHeight) * 0.5)

    logger.print('### positionX = ' .. tostring(positionX) .. ', positionY = ' .. tostring(positionY))

    if (positionX + windowWidth) > gameContentRect.w then
        positionX = math.max(0, gameContentRect.w - windowWidth)
    end
    if (positionY + windowHeight) > gameContentRect.h then
        positionY = math.max(0, gameContentRect.h - windowHeight -100)
    end
    logger.print('### final position x = ' .. tostring(positionX) .. ', y = ' .. tostring(positionY))
    window:setPosition(math.floor(positionX), math.floor(positionY))
end
---@param signalModelIds table{signalModelId_EraA integer, signalModelId_EraC integer, signalModelId_Invisible integer}
utils.showNearbySignalPicker = function(signalModelIds)
    local topBarLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')

    local list = api.gui.comp.List.new(false, api.gui.util.Orientation.VERTICAL, false)
    list:setDeselectAllowed(false)
    list:setVerticalScrollBarPolicy(0) -- 0 as needed 1 always off 2 always show 3 simple

    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    layout:addItem(topBarLayout)
    layout:addItem(list)

    local window = api.gui.util.getById(constants.guiIds.signalLocatorWindowId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.signalLocatorWindowTitle, layout)
        window:setId(constants.guiIds.signalLocatorWindowId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    local function setWindowSize()
        window:setResizable(true)
        local gameContentRect = api.gui.util.getGameUI():getContentRect()
        local size = api.gui.util.Size.new()
        size.h = math.ceil(gameContentRect.h / 2)
        size.w = math.ceil(gameContentRect.w / 2)
        window:setMaximumSize(size)
    end
    setWindowSize()

    local function addJoinButtons()
        if not(signalModelIds) then return end

        local signalIds_indexed = signalHelpers.getAllEdgeObjectsWithModelIds_indexed(
            signalModelIds.signalModelId_EraA,
            signalModelIds.signalModelId_EraC,
            signalModelIds.signalModelId_Invisible,
            false
        )
        local components = {}
        for signalId, _ in pairs(signalIds_indexed) do
            if signalHelpers.isValidAndExistingId(signalId) then
                local signalName_struct = api.engine.getComponent(signalId, api.type.ComponentType.NAME)
                local nameTextView = api.gui.comp.TextView.new(signalName_struct and signalName_struct.name or '')

                local idTextView = api.gui.comp.TextView.new(tostring(signalId))

                local gotoButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
                gotoButtonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/locate_small.tga'))
                gotoButtonLayout:addItem(api.gui.comp.TextView.new(_texts.goThere))
                local gotoButton = api.gui.comp.Button.new(gotoButtonLayout, true)
                gotoButton:onClick(
                    function()
                        if not(signalHelpers.isValidAndExistingId(signalId)) then return end
                        utils.goToEntity(signalId)
                        -- game.gui.setCamera({con.position[1], con.position[2], 100, 0, 0})
                    end
                )

                components[#components + 1] = {idTextView, nameTextView, gotoButton}
            end
        end

        if #components > 0 then
            -- local guiSignalTable = api.gui.comp.Table.new(#components, 'NONE') -- one of "NONE", "SELECTABLE" or "MULTI"
            -- guiSignalTable:setNumCols(3)
            local guiSignalTable = api.gui.comp.Table.new(3, 'NONE') -- num of columns, one of "NONE", "SELECTABLE" or "MULTI"
            -- guiSignalTable:setColWeight(0, .3)
            -- guiSignalTable:setColWeight(1, .3)
            -- guiSignalTable:setColWeight(2, .4)
            for _, value in pairs(components) do
                guiSignalTable:addRow(value)
            end
            -- layout:addItem(guiSignalTable)
            list:addItem(guiSignalTable)
        end
    end
    addJoinButtons()

    local function addTopBar()
        local infoIcon = api.gui.comp.ImageView.new('ui/button/medium/info.tga')
        infoIcon:setTooltip(_texts.note)

        local refreshButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
        local refreshImg = api.gui.comp.ImageView.new('ui/button/small/vehicle_replace_active.tga')
        refreshImg:setTooltip(_texts.refresh)
        refreshButtonLayout:addItem(refreshImg, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        local refreshButton = api.gui.comp.Button.new(refreshButtonLayout, true)
        refreshButton:onClick(function()
            if not(list) then return end
            list:clear(false)
            addJoinButtons()
        end)

        topBarLayout:addItem(infoIcon)
        topBarLayout:addItem(refreshButton)
    end
    addTopBar()

    local position = api.gui.util.getMouseScreenPos()
    -- position.x = position.x + _windowXShift
    position.y = position.y + _windowYShift
    utils.setWindowPosition(window, position)

    window:onClose(
        function()
            window:setVisible(false, false)
        end
    )
end

local guiHelpers = {
    initLocatorButton = function(funcOfNowt)
        if api.gui.util.getById(constants.guiIds.locatorButtonId) then return end

        local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
        local img = api.gui.comp.ImageView.new('ui/lollo_priority_signals/locate.tga')
        img:setTooltip(_texts.locator)
        buttonLayout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        local button = api.gui.comp.Button.new(buttonLayout, true)
        button:onClick(function()
            local signalModelIds = funcOfNowt()
            utils.showNearbySignalPicker(signalModelIds)
        end)
        button:setId(constants.guiIds.locatorButtonId)

        api.gui.util.getById('gameInfo'):getLayout():addItem(button) -- adds a button in the right place
    end,
    initNotausButton = function(isDynamicOn, funcOfBool)
        if api.gui.util.getById(constants.guiIds.dynamicOnOffButtonId) then return end

        local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
        utils.modifyOnOffButtonLayout(buttonLayout, isDynamicOn)
        local button = api.gui.comp.ToggleButton.new(buttonLayout)
        button:setSelected(isDynamicOn, false)
        button:onToggle(function(isOn) -- isOn is boolean
            logger.print('toggled; isOn = ', isOn)
            while buttonLayout:getNumItems() > 0 do
                local item0 = buttonLayout:getItem(0)
                buttonLayout:removeItem(item0)
            end
            utils.modifyOnOffButtonLayout(buttonLayout, isOn)
            button:setSelected(isOn, false)
            funcOfBool(isOn)
        end)

        button:setId(constants.guiIds.dynamicOnOffButtonId)

        api.gui.util.getById('gameInfo'):getLayout():addItem(button) -- adds a button in the right place
    end,
}

return guiHelpers
