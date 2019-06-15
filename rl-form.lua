obs           	= obslua
source_name   	= ""
images			= nil
total_states 	= 0
cur_state		= 0
activated     	= false
reset_hotkey_id = obs.OBS_INVALID_HOTKEY_ID
win_hotkey_id	= obs.OBS_INVALID_HOTKEY_ID
lose_hotkey_id	= obs.OBS_INVALID_HOTKEY_ID
ranks 			= {}

ranked_game_modes = {["10"] = "Ranked Duel",["11"] = "Ranked Doubles",["12"] = "Ranked Solo Standard",["13"] = "Ranked Standard"}

function timer_callback()
	sync_rating()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating
	if activating then
		set_form_image()
		obs.timer_add(timer_callback, interval)
		open_rank_logs()
	else
		obs.timer_remove(timer_callback)
		close_rank_logs()
	end
end

function set_form_image()
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil and total_states > 0 then
		local settings = obs.obs_data_create()
		local currentImage = obs.obs_data_array_item(images, cur_state)
		if currentImage ~= nil then
			obs.obs_data_set_string(settings, "file", obs.obs_data_get_string(currentImage,"value"))
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)			
		end
	end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end

	activate(false)
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	cur_state		= math.floor(total_states / 2)
	reset(true)
	return false
end

function increment_form()
	if cur_state < (total_states - 1) then
		print("Rank incremented!")
		cur_state = cur_state + 1
		set_form_image()
	end
end

function decrement_form() 
	if cur_state > 0 then
		print("Rank decremented!")
		cur_state = cur_state - 1
		set_form_image()
	end
end

----------------------------------------------------------

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_int(props, "interval", "Update Interval (seconds)", 5, 3600, 1)

	local sourceList = obs.obs_properties_add_list(props, "source", "Image Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local p = obs.obs_properties_add_editable_list(props, "images", "Images", obs.OBS_EDITABLE_LIST_TYPE_FILES, "*.png", nil)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "image_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(sourceList, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	obs.obs_properties_add_path(props, "bakkes_log", "BakkesMod Log File", obs.OBS_PATH_FILE,"*.log",nil)
	obs.obs_properties_add_button(props, "reset_button", "Reset Stats", reset_button_clicked)
	obs.obs_properties_add_button(props, "add_win_button", "Add Win", increment_form)
	obs.obs_properties_add_button(props, "add_loss_button", "Add Loss", decrement_form)	
	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Sets an image source to act as a display for Rocket League form.\n\nMade by Kentraree, modified countdown script by Jim"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	activate(false)

	if images ~= nil then
		obs.obs_data_array_release(images)
	end

	interval = obs.obs_data_get_int(settings, "interval")
	source_name = obs.obs_data_get_string(settings, "source")
	images = obs.obs_data_get_array(settings, "images")
	total_states 	= obs.obs_data_array_count(images)
	cur_state		= math.floor(total_states / 2)
	bakkes_log_file = obs.obs_data_get_string(settings, "bakkes_log")
	print("Total " .. total_states .. " current " .. cur_state)

	reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "interval", 5000)
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(reset_hotkey_id)
	obs.obs_data_set_array(settings, "rl_form.reset", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

	hotkey_save_array = obs.obs_hotkey_save(win_hotkey_id)
	obs.obs_data_set_array(settings, "rl_form.increment", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	
	hotkey_save_array = obs.obs_hotkey_save(lose_hotkey_id)
	obs.obs_data_set_array(settings, "rl_form.decrement", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)	
end

-- a function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	--
	-- NOTE: These particular script callbacks do not necessarily have to
	-- be disconnected, as callbacks will automatically destroy themselves
	-- if the script is unloaded.  So there's no real need to manually
	-- disconnect callbacks that are intended to last until the script is
	-- unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	reset_hotkey_id = obs.obs_hotkey_register_frontend("rl_form.reset", "Reset RL Form", reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "rl_form.reset")
	obs.obs_hotkey_load(reset_hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

	win_hotkey_id = obs.obs_hotkey_register_frontend("rl_form.increment", "Increment RL Form ", increment_form)
	hotkey_save_array = obs.obs_data_get_array(settings, "rl_form.increment")
	obs.obs_hotkey_load(win_hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

	lose_hotkey_id = obs.obs_hotkey_register_frontend("rl_form.decrement", "Decrement RL Form ", decrement_form)
	hotkey_save_array = obs.obs_data_get_array(settings, "rl_form.decrement")
	obs.obs_hotkey_load(lose_hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- [17:19:12] [RankTrackMod] Synced rating for 10. Old: 0, new: 34.7317
-- [17:19:12] [RankTrackMod] Synced rating for 11. Old: 0, new: 48.0583
-- [17:19:12] [RankTrackMod] Synced rating for 12. Old: 0, new: 36.7712
-- [17:19:12] [RankTrackMod] Synced rating for 13. Old: 0, new: 52.7905
-- [17:19:12] [RankTrackMod] Synced rating for 27. Old: 0, new: 35.4177
-- [17:19:12] [RankTrackMod] Synced rating for 28. Old: 0, new: 23.6091
-- [17:19:12] [RankTrackMod] Synced rating for 29. Old: 0, new: 25.7645

function open_rank_logs() 
	print("Attempting to open log file " .. bakkes_log_file)
	if bakkes_log_file ~= nil then
		log_file = io.open(bakkes_log_file, "r")
	end
end

function close_rank_logs()
	if log_file then
		log_file:close()
		log_file = nil
	end
end

function sync_rating() 
	if log_file == nil then
		return
	end

	local stored_ratings = {}

	for line in log_file:lines() do
		print("Line")
		local columns = {}
		local index = 1 
		for column in string.gmatch( line, "[^%s]+" ) do
			columns[index] = column
			index = index + 1
		end

		if columns[2] == "[RankTrackMod]" and columns[3] == "Synced" and columns[4] == "rating" then
			
			mode = tostring(tonumber(columns[6]))
			if ranked_game_modes[mode] ~= nil then
				stored_ratings[mode] = tostring(tonumber(columns[10])) -- Sneaky way to strip the dot
			end
		end
	end

	for mode, rating in pairs(stored_ratings) do
		local newScore = stored_ratings[mode]
		local oldScore = ranks[mode]
		local balance = 0
		if oldScore ~= nil then
			if newScore > oldScore then
				balance = balance + 1
			elseif newScore < oldScore then
				balance = balance - 1
			end
		end

		if balance > 0 then
			increment_form()
		elseif balance < 0 then
			decrement_form()
		end
		ranks[mode] = newScore
		print("Rank for mode " .. mode .. " is " .. rating)
	end
end

