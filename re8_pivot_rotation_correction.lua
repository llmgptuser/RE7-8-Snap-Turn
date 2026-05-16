local game_name = reframework:get_game_name()
local is_re7 = game_name == "re7"
local is_re8 = game_name == "re8"

if not is_re7 and not is_re8 then
    return
end

local cfg = {
    pivot_rotation_correction_enabled = false,
}

local cfg_path = "re8_vr/pivot_rotation_correction_config.json"

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

re.on_draw_ui(function()
    local changed = false
    if imgui.tree_node("Pivot Rotation Correction") then
        changed, cfg.pivot_rotation_correction_enabled = imgui.checkbox("Enabled (Disable Roomscale Movement first!)", cfg.pivot_rotation_correction_enabled)
        imgui.tree_pop()
    end
end)

local is_crouch = false

sdk.hook(
    sdk.find_type_definition(sdk.game_namespace("PlayerStatus")):get_method("get_isCrouch"),
    function(args)
    end,
    function(retval)
        is_crouch = ((sdk.to_int64(retval) & 1) == 1)
        return retval
    end
)

sdk.hook(
    sdk.find_type_definition(sdk.game_namespace("PlayerCamera.CameraController")):get_method("calcDeltaHorizontalRotation"),
    function(args)
    end,
    function(retval)
        if not vrmod:is_hmd_active() or not cfg.pivot_rotation_correction_enabled then
            return retval
        end

        local quat = vrmod:get_rotation(0):to_quat()
        local forward = quat * Vector3f.new(0, 0, 1)
        local yaw_radians = math.atan(forward.x, forward.z)

        if is_crouch then
            pivot_h_radius = 0.23
            local x = -math.sin(yaw_radians) * pivot_h_radius
            local z = -math.cos(yaw_radians) * pivot_h_radius
            local origin = Vector3f.new(x, 0, z+0.14)
            vrmod:set_standing_origin(origin)
        else
            pivot_h_radius = 0.08
            local x = -math.sin(yaw_radians) * pivot_h_radius
            local z = -math.cos(yaw_radians) * pivot_h_radius
            local origin = Vector3f.new(x, 0, z)
            vrmod:set_standing_origin(origin)  
        end

        return retval
    end
)