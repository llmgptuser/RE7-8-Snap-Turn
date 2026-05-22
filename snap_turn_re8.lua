local game_name = reframework:get_game_name()
local is_re7 = game_name == "re7"
local is_re8 = game_name == "re8"

if not is_re7 and not is_re8 then
    return
end

local re8 = require("utility/RE8")

local cfg = {
    snap_turn_enabled = true,
    snap_turn_back_enabled = true,
    snap_turn_angle = 45.0,
    tilt_threshold = 0.8,
    recenter_threshold = 0.4,
    smooth_turn_speed = 10.0,
}

local cfg_path = "re8_vr/snap_turn_config.json"

local function load_cfg()
    local loaded_cfg = json.load_file(cfg_path)

    if loaded_cfg == nil then
        json.dump_file(cfg_path, cfg)
        return
    end

    for k, v in pairs(loaded_cfg) do
        cfg[k] = v
    end
end

load_cfg()

re.on_config_save(function()
    json.dump_file(cfg_path, cfg)
end)

local gamepad_singleton_t = sdk.find_type_definition("via.hid.GamePad")

local function get_right_input_axis()
    if vrmod:is_using_controllers() then
        local axis = vrmod:get_right_stick_axis()
        return axis
    end

    local gamepad_singleton = sdk.get_native_singleton("via.hid.GamePad")
    if not gamepad_singleton then return Vector2f.new(0, 0) end

    local pad = sdk.call_native_func(gamepad_singleton, gamepad_singleton_t, "get_LastInputDevice")
    if not pad then return Vector2f.new(0, 0) end

    return pad:get_AxisR()
end

local function math_sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

local is_stick_centered = true
local is_stick_centered_y = true
local snap_turn_back = false

sdk.hook(
    sdk.find_type_definition(sdk.game_namespace("PlayerCamera.CameraController")):get_method("calcDeltaHorizontalRotation"),
    function(args)
    end,
    function(retval)
        if not vrmod:is_hmd_active() or not re8vr.player then
            return retval
        end

        if is_re7 then
            local menu_manager = sdk.get_managed_singleton("app.MenuManager")
            if menu_manager ~= nil then
                if menu_manager:call("isOpenInventoryMenu") then
                    return retval
                end
                if not menu_manager:call("isCanOpenQuickSlotMenu") then
                    return retval
                end                
            end
        end

        if is_re8 then
            local GUIManager = sdk.get_managed_singleton("app.GUIManager")
            if GUIManager ~= nil then
                if GUIManager:call("isShowingGUIInventory") then
                    return retval
                end
                if GUIManager:call("isShowingGUIShop") then
                    return retval
                end
            end
        end

        local right_stick_axis = get_right_input_axis()
        local x_axis = right_stick_axis.x
        local y_axis = right_stick_axis.y
        if cfg.snap_turn_enabled then
            if is_stick_centered then
                if math.abs(x_axis) > cfg.tilt_threshold then
                    is_stick_centered = false
                    return sdk.float_to_ptr(math_sign(x_axis) * cfg.snap_turn_angle)
                end
            elseif math.abs(x_axis) < cfg.recenter_threshold then
                is_stick_centered = true
            end
            if cfg.snap_turn_back_enabled and is_stick_centered then
                if is_stick_centered_y then
                    if y_axis < -cfg.tilt_threshold then
                        is_stick_centered_y = false
                        return sdk.float_to_ptr(180.0)
                    end
                elseif math.abs(y_axis) < cfg.recenter_threshold then
                    is_stick_centered_y = true
                end
            end
        else
            return sdk.float_to_ptr(x_axis * cfg.smooth_turn_speed)
        end
        return sdk.float_to_ptr(0.0)
    end
)


re.on_draw_ui(function()
    local changed = false
    if imgui.tree_node("Enhanced Movement") then
        changed, cfg.snap_turn_enabled = imgui.checkbox("Snap Turn Enabled", cfg.snap_turn_enabled)
        if cfg.snap_turn_enabled then
            changed, cfg.snap_turn_angle = imgui.drag_float("Snap Turn Angle", cfg.snap_turn_angle, 15.0, 15.0, 90.0)
            changed, cfg.snap_turn_back_enabled = imgui.checkbox("Tild Down to Turn Back Enabled", cfg.snap_turn_back_enabled)
            changed, cfg.tilt_threshold = imgui.drag_float("Snap Turn Tilt Threshold", cfg.tilt_threshold, 0.05, 0.1, 1.0)
            changed, cfg.recenter_threshold = imgui.drag_float("Snap Turn Recenter Threshold", cfg.recenter_threshold, 0.05, 0.1, 1.0)
        else
            changed, cfg.smooth_turn_speed = imgui.drag_float("Smooth Turn Speed", cfg.smooth_turn_speed, 1.0, 1.0, 50.0)
        end
        imgui.tree_pop()
    end
end)
