class_name SteamSetup
extends Node2D

const STEAM_FULL_APP_ID := 3640430
const STEAM_DEMO_APP_ID := 4567730

func _ready() -> void:
	var app_id := STEAM_DEMO_APP_ID if OS.has_feature('demo') else STEAM_FULL_APP_ID
	var initialize_response := Steam.steamInitEx(app_id, true)
	if initialize_response['status'] != Steam.STEAM_API_INIT_RESULT_OK:
		push_warning('Failed to initialize steam: ' + str(initialize_response))
		return

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func get_mod_folders() -> Array[String]:
	var result: Array[String]
	var subscribed_items: Array = Steam.getSubscribedItems()
	for item_id: int in subscribed_items:
		var item_state: int = Steam.getItemState(item_id)
		if item_state & Steam.ITEM_STATE_INSTALLED:
			var install_info: Dictionary = Steam.getItemInstallInfo(item_id)
			if install_info.get('ret', false) and install_info.get('folder', ''):
				result.append(install_info['folder'] as String)
	return result

func create_mod(folder_path: String, title: String) -> int:
	Steam.createItem(Steam.getAppID(), Steam.WORKSHOP_FILE_TYPE_COMMUNITY)
	var item_creation_result: Array = await Steam.item_created
	var result: int = item_creation_result[0]
	var file_id: int = item_creation_result[1]
	var accept_tos: bool = item_creation_result[2]
	if result != Steam.RESULT_OK:
		await GlobalUI.show_confirm(
			tr('Steam Upload Error'),
			tr('Workshop item creation failed with error code: %s') % result,
			tr('Ok'), '').confirmed
		return 0

	if accept_tos:
		Steam.activateGameOverlayToWebPage('steam://url/CommunityFilePage/%d' % file_id)
	var update_handle: int = Steam.startItemUpdate(Steam.getAppID(), file_id)
	Steam.setItemVisibility(update_handle, Steam.REMOTE_STORAGE_PUBLISHED_VISIBILITY_PRIVATE)
	Steam.submitItemUpdate(update_handle)
	return await update_mod(file_id, folder_path, title)

func update_mod(file_id: int, folder_path: String, title: String = '') -> int:
	var update_handle: int = Steam.startItemUpdate(Steam.getAppID(), file_id)

	if title:
		Steam.setItemTitle(update_handle, title)
	Steam.setItemContent(update_handle, folder_path)

	Steam.submitItemUpdate(update_handle)
	var update_result: int = (await Steam.item_updated)[0]
	if update_result != Steam.RESULT_OK:
		await GlobalUI.show_confirm(
			tr('Steam Upload Error'),
			tr('Workshop item creation failed with error code: %s') % update_result,
			tr('Ok'), '').confirmed
		return 0

	Steam.subscribeItem(file_id)
	var sub_result_arr: Array = await Steam.subscribe_item
	var sub_result: int = sub_result_arr[0]
	var sub_file_id: int = sub_result_arr[1]
	if not Utils.ensure(sub_file_id == file_id):
		return file_id  # We should only ever be updating one at a time.
	if sub_result != Steam.RESULT_OK:
		await GlobalUI.show_confirm(
			tr('Steam Upload Success!'),
			tr('Workshop item updated successfully.\n\nBUT automatic subscribe failed. Subscribe and restart to edit.'),
			tr('Ok'), '').confirmed
		return file_id

	if not Steam.downloadItem(file_id, true):
		await GlobalUI.show_confirm(
			tr('Steam Upload Success!'),
			tr('Workshop item updated and subscribed successfully.\n\nBUT automatic download failed. Steam restart may be required.'),
			tr('Ok'), '').confirmed
		return file_id

	var dl_result_arr: Array = await Steam.item_downloaded
	var dl_result: int = dl_result_arr[0]
	var dl_file_id: int = dl_result_arr[1]
	if Utils.ensure(dl_file_id == file_id):
		# We should only ever be downloading one at a time.
		if dl_result == Steam.RESULT_OK:
			await GlobalUI.show_confirm(
				tr('Steam Upload Success!'),
				tr('Workshop item updated and downloaded successfully.'),
				tr('Ok'), '').confirmed
		else:
			await GlobalUI.show_confirm(
				tr('Steam Upload Success!'),
				tr('Workshop item updated and subscribed successfully.\n\nBUT automatic download may have failed. Steam restart may be required.'),
				tr('Ok'), '').confirmed
	return file_id

func can_update_mod(file_id: int) -> bool:
	var query_handle := Steam.createQueryUGCDetailsRequest([file_id])
	Steam.sendQueryUGCRequest(query_handle)
	var response: Array
	while true:
		response = await Steam.ugc_query_completed
		if response[0] == query_handle:
			break

	var result: int = response[1]
	var results_returned: int = response[2]
	var can_update := false

	if result == Steam.RESULT_OK and results_returned > 0:
		var details: Dictionary = Steam.getQueryUGCResult(query_handle, 0)
		if details.get('result', Steam.RESULT_NONE) == Steam.RESULT_OK:
			can_update = details.get('steam_id_owner', 0) == Steam.getSteamID()

	Steam.releaseQueryUGCRequest(query_handle)
	return can_update
