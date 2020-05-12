local cached_translations = {}

local translator = {
	OnGoing = {},
	CurrentID = 1
}

local language_lookup = {
	["Automatic"] = "auto",

	["Afrikaans"] = "af", ["Irish"] = "ga", ["Albanian"] = "sq", ["Italian"] = "it", ["Arabic"] = "ar", ["Japanese"] = "ja",
	["Azerbaijani"] = "az", ["Kannada"] = "kn", ["Basque"] = "eu", ["Korean"] = "ko", ["Bengali"] = "bn", ["Latin"] = "la",
	["Belarusian"] = "be", ["Latvian"] = "lv", ["Bulgarian"] =	"bg", ["Lithuanian"] = "lt", ["Catalan"] = "ca",
	["Macedonian"] = "mk", ["Chinese Simplified"] = "zh-CN", ["Malay"] =	"ms", ["Chinese Traditional"] = "zh-TW", ["Maltese"] = "mt",
	["Croatian"] = "hr", ["Norwegian"] = "no", ["Czech"] = "cs", ["Persian"] = "fa", ["Danish"] = "da", ["Polish"] = "pl", ["Dutch"] = "nl",
	["Portuguese"] = "pt", ["English"] = "en", ["Romanian"] = "ro", ["Esperanto"] =	"eo", ["Russian"] = "ru", ["Estonian"] = "et", ["Serbian"] = "sr",
	["Filipino"] = "tl", ["Slovak"] = "sk", ["Finnish"] = "fi", ["Slovenian"] =	"sl", ["French"] = "fr", ["Spanish"] = "es", ["Galician"] = "gl",
	["Swahili"] = "sw", ["Georgian"] = "ka", ["Swedish"] = "sv", ["German"] = "de", ["Tamil"] =	"ta", ["Greek"] = "el", ["Telugu"] = "te",
	["Gujarati"] = "gu", ["Thai"] = "th", ["Haitian Creole"] = "ht", ["Turkish"] = "tr", ["Hebrew"] = "iw", ["Ukrainian"] =	"uk", ["Hindi"] = "hi",
	["Urdu"] = "ur", ["Hungarian"] = "hu", ["Vietnamese"] = "vi", ["Icelandic"] = "is", ["Welsh"] = "cy", ["Indonesian"] = "id", ["Yiddish"] = "yi",
}

local valid_languages = {}
for _, country_code in pairs(language_lookup) do
	valid_languages[country_code] = true
end

local red_col = Color(255, 0, 0)
local function create_translation_panel(self)
	local tr_panel = vgui.Create("DHTML")
	tr_panel:SetHTML("<html><head></head><body></body></html>")
	tr_panel:SetAllowLua(true)
	tr_panel:AddFunction("Translate", "Print", print)
	tr_panel:AddFunction("Translate", "Callback", function(id, status, json, target_lang)
		local callback = self.OnGoing[id]
		if not callback then return end

		if status ~= 200 then
			if status == 429 then
				chat.AddText(red_col, "[WARN] It seems that you have been blocked from using the translation service for a while.")
				chat.AddText(red_col, "This is most likely the result of spam. Disabling translation to prevent a longer waiting time.")
				self.Disabled = true
			end

			callback(false)
			self.OnGoing[id] = nil
			return
		end

		local data = util.JSONToTable(json)
		if not data then
			callback(false)
			self.OnGoing[id] = nil
			return
		end

		local translation, source = data[1][1][1], data[1][1][2]

		cached_translations[source] = cached_translations[source] or {}
		cached_translations[source][target_lang] = translation

		callback(true, source, translation)
		self.OnGoing[id] = nil
	end)

	tr_panel:QueueJavascript([[
	function TranslateRequest(url, id, targetLang) {
		var request = new XMLHttpRequest();
		request.open("GET", url);
		request.send();

		request.onerror = function() {
			Translate.Callback(id, 0);
		};

		request.onreadystatechange = function() {
			if (this.readyState == 4) {
				Translate.Callback(id, this.status, request.responseText, targetLang);
			}
		};
	}]])

	return tr_panel
end

function translator:Initialize()
	self.Panel = create_translation_panel(self)
	self.OnGoing = {}
	self.CurrentID = 1
end

function translator:Destroy()
	if IsValid(self.Panel) then
		self.Panel:Remove()
	end

	for id, callback in pairs(self.OnGoing) do
		callback(false)
		self.OnGoing[id] = nil
	end

	self.CurrentID = 1
end

function translator:Translate(text, source_lang, target_lang, on_finish)
	if not valid_languages[source_lang] or not valid_languages[target_lang] then
		on_finish(false)
		return
	end

	if cached_translations[text] and cached_translations[text][target_lang] then
		on_finish(true, text, cached_translations[text][target_lang])
		return
	end

	if self.Disabled then
		on_finish(false)
		return
	end

	if not IsValid(self.Panel) then
		self.Panel = create_translation_panel(self)
	end

	self.OnGoing[self.CurrentID] = on_finish

	local url = ("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s")
		:format(source_lang, target_lang, text)
	self.Panel:QueueJavascript(("TranslateRequest(%q,%d,%q);"):format(url, self.CurrentID, target_lang))

	self.CurrentID = self.CurrentID + 1
end

return translator