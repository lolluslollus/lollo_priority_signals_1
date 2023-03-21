local constants = require('lollo_priority_signals.constants')
local logger = require('lollo_priority_signals.logger')
local stringUtils = require('lollo_priority_signals.stringUtils')


local _texts = {
    signalsOff = _('PrioritySignalsOff'),
    signalsOn = _('PrioritySignalsOn'),
    warningWindowTitle = _('WarningWindowTitle'),
}

local _windowXShift = -200

local utils = {
    moveCamera = function(position123)
        -- logger.print('moveCamera starting, position123 =') logger.debugPrint(position123)
        local cameraData = game.gui.getCamera()
        game.gui.setCamera({position123[1], position123[2], cameraData[3], cameraData[4], cameraData[5]})
    end,
    modifyOnOffButtonLayout = function(layout, isOn)
        local img = nil
        if isOn then
            -- img = api.gui.comp.ImageView.new('ui/design/components/checkbox_valid.tga')
            img = api.gui.comp.ImageView.new('ui/lollo_priority_signals/checkbox_valid.tga')
            img:setTooltip(_texts.signalsOn)
            layout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
            -- layout:addItem(api.gui.comp.TextView.new(_texts.dynamicOn), api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        else
            img = api.gui.comp.ImageView.new('ui/lollo_priority_signals/checkbox_invalid.tga')
            img:setTooltip(_texts.signalsOff)
            layout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
            -- layout:addItem(api.gui.comp.TextView.new(_texts.dynamicOff), api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        end
    end
}

local guiHelpers = {
    showWarningWindowWithMessage = function(text)
        local layout = api.gui.layout.BoxLayout.new('VERTICAL')
        local window = api.gui.util.getById(constants.guiIds.warningWindowWithMessageId)
        if window == nil then
            window = api.gui.comp.Window.new(_texts.warningWindowTitle, layout)
            window:setId(constants.guiIds.warningWindowWithMessageId)
        else
            window:setContent(layout)
            window:setVisible(true, false)
        end

        layout:addItem(api.gui.comp.TextView.new(text))

        window:setHighlighted(true)
        local position = api.gui.util.getMouseScreenPos()
        window:setPosition(position.x + _windowXShift, position.y)
        -- window:addHideOnCloseHandler()
        window:onClose(
            function()
                window:setVisible(false, false)
            end
        )
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
