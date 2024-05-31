;
; Chrome.ahk 1.3.0
; Copyright (c) 2023 Philip Taylor (known also as GeekDude, G33kDude) and contributors
; https://github.com/G33kDude/Chrome.ahk
;
; MIT License
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;

class Chrome
{
	static version := "1.3.0"
	
	static DebugPort := 9222
	
	/*
		Escape a string in a manner suitable for command line parameters
	*/
	CliEscape(Param)
	{
		return """" RegExReplace(Param, "(\\*)""", "$1$1\""") """"
	}
	
	/*
		Finds instances of chrome in debug mode and the ports they're running
		on. If no instances are found, returns a false value. If one or more
		instances are found, returns an associative array where the keys are
		the ports, and the values are the full command line texts used to start
		the processes.
		
		One example of how this may be used would be to open chrome on a
		different port if an instance of chrome is already open on the port
		you wanted to used.
		
		```
		; If the wanted port is taken, use the largest taken port plus one
		DebugPort := 9222
		if (Chromes := Chrome.FindInstances()).HasKey(DebugPort)
			DebugPort := Chromes.MaxIndex() + 1
		ChromeInst := new Chrome(ProfilePath,,,, DebugPort)
		```
		
		Another use would be to scan for running instances and attach to one
		instead of starting a new instance.
		
		```
		if (Chromes := Chrome.FindInstances())
			ChromeInst := {"base": Chrome, "DebugPort": Chromes.MinIndex()}
		else
			ChromeInst := new Chrome(ProfilePath)
		```
	*/
	FindInstances()
	{
		static Needle := "--remote-debugging-port=(\d+)"
		Out := {}
		for Item in ComObjGet("winmgmts:")
			.ExecQuery("SELECT CommandLine FROM Win32_Process"
			. " WHERE Name = 'chrome.exe'")
			if RegExMatch(Item.CommandLine, Needle, Match)
				Out[Match1] := Item.CommandLine
		return Out.MaxIndex() ? Out : False
	}
	
	/*
		ProfilePath - Path to the user profile directory to use. Will use the standard if left blank.
		URLs        - The page or array of pages for Chrome to load when it opens
		Flags       - Additional flags for chrome when launching
		ChromePath  - Path to chrome.exe, will detect from start menu when left blank
		DebugPort   - What port should Chrome's remote debugging server run on
	*/
	__New(ProfilePath:="", URLs:="about:blank", Flags:="", ChromePath:="", DebugPort:="")
	{
		; Verify ProfilePath
		if (ProfilePath != "" && !InStr(FileExist(ProfilePath), "D"))
			throw Exception("The given ProfilePath does not exist")
		cc := DllCall("GetFullPathName", "str", ProfilePath, "uint", 0, "ptr", 0, "ptr", 0, "uint")
		VarSetCapacity(buf, cc*(A_IsUnicode?2:1))
		DllCall("GetFullPathName", "str", ProfilePath, "uint", cc, "str", buf, "ptr", 0, "uint")
		this.ProfilePath := ProfilePath := buf
		
		; Verify ChromePath
		if (ChromePath == "")
			; By using winmgmts to get the path of a shortcut file we fix an edge case where the path is retreived incorrectly
			; if using the ahk executable with a different architecture than the OS (using 32bit AHK on a 64bit OS for example)
			ChromePath := ComObjGet("winmgmts:").ExecQuery("Select * from Win32_ShortcutFile where Name=""" StrReplace(A_StartMenuCommon "\Programs\Google Chrome.lnk", "\", "\\") """").ItemIndex(0).Target
			; FileGetShortcut, %A_StartMenuCommon%\Programs\Google Chrome.lnk, ChromePath
		if (ChromePath == "")
			RegRead, ChromePath, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe
		if !FileExist(ChromePath)
			throw Exception("Chrome could not be found")
		this.ChromePath := ChromePath
		
		; Verify DebugPort
		if (DebugPort != "")
		{
			if DebugPort is not integer
				throw Exception("DebugPort must be a positive integer")
			else if (DebugPort <= 0)
				throw Exception("DebugPort must be a positive integer")
			this.DebugPort := DebugPort
		}
		
		; Escape the URL(s)
		URLString := ""
		for Index, URL in IsObject(URLs) ? URLs : [URLs]
			URLString .= " " this.CliEscape(URL)
		
		Run, % this.CliEscape(ChromePath)
		. " --remote-debugging-port=" this.DebugPort
		. " --remote-allow-origins=*"
		. (ProfilePath ? " --user-data-dir=" this.CliEscape(ProfilePath) : "")
		. (Flags ? " " Flags : "")
		. URLString
		,,, OutputVarPID
		this.PID := OutputVarPID
	}
	
	/*
		End Chrome by terminating the process.
	*/
	Kill()
	{
		Process, Close, % this.PID
	}
	
	/*
		Queries chrome for a list of pages that expose a debug interface.
		In addition to standard tabs, these include pages such as extension
		configuration pages.
	*/
	GetPageList()
	{
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.open("GET", "http://127.0.0.1:" this.DebugPort "/json")
		http.send()
		return this.JSON.Load(http.responseText)
	}
	
	/*
		Returns a connection to the debug interface of a page that matches the
		provided criteria. When multiple pages match the criteria, they appear
		ordered by how recently the pages were opened.
		
		Key        - The key from the page list to search for, such as "url" or "title"
		Value      - The value to search for in the provided key
		MatchMode  - What kind of search to use, such as "exact", "contains", "startswith", or "regex"
		Index      - If multiple pages match the given criteria, which one of them to return
		fnCallback - A function to be called whenever message is received from the page
	*/
	GetPageBy(Key, Value, MatchMode:="exact", Index:=1, fnCallback:="", fnClose:="")
	{
		Count := 0
		for n, PageData in this.GetPageList()
		{
			if (((MatchMode = "exact" && PageData[Key] = Value) ; Case insensitive
				|| (MatchMode = "contains" && InStr(PageData[Key], Value))
				|| (MatchMode = "startswith" && InStr(PageData[Key], Value) == 1)
				|| (MatchMode = "regex" && PageData[Key] ~= Value))
				&& ++Count == Index)
				return new this.Page(PageData.webSocketDebuggerUrl, fnCallback, fnClose)
		}
	}
	
	/*
		Shorthand for GetPageBy("url", Value, "startswith")
	*/
	GetPageByURL(Value, MatchMode:="startswith", Index:=1, fnCallback:="", fnClose:="")
	{
		return this.GetPageBy("url", Value, MatchMode, Index, fnCallback, fnClose)
	}
	
	/*
		Shorthand for GetPageBy("title", Value, "startswith")
	*/
	GetPageByTitle(Value, MatchMode:="startswith", Index:=1, fnCallback:="", fnClose:="")
	{
		return this.GetPageBy("title", Value, MatchMode, Index, fnCallback, fnClose)
	}
	
	/*
		Shorthand for GetPageBy("type", Type, "exact")
		
		The default type to search for is "page", which is the visible area of
		a normal Chrome tab.
	*/
	GetPage(Index:=1, Type:="page", fnCallback:="", fnClose:="")
	{
		return this.GetPageBy("type", Type, "exact", Index, fnCallback, fnClose)
	}
	
	/*
		Connects to the debug interface of a page given its WebSocket URL.
	*/
	class Page
	{
		Connected := False
		ID := 0
		Responses := []
		
		/*
			wsurl      - The desired page's WebSocket URL
			fnCallback - A function to be called whenever message is received
			fnClose    - A function to be called whenever the page connection is lost
		*/
		__New(wsurl, fnCallback:="", fnClose:="")
		{
			this.fnCallback := fnCallback
			this.fnClose := fnClose
			this.BoundKeepAlive := this.Call.Bind(this, "Browser.getVersion",, False)
			
			; TODO: Throw exception on invalid objects
			if IsObject(wsurl)
				wsurl := wsurl.webSocketDebuggerUrl
			
			ws := {"base": this.WebSocket, "_Event": this.Event, "Parent": this}
			this.ws := new ws(wsurl)
			
			while !this.Connected
				Sleep, 50
		}
		
		/*
			Calls the specified endpoint and provides it with the given
			parameters.
			
			DomainAndMethod - The endpoint domain and method name for the
			endpoint you would like to call. For example:
			PageInst.Call("Browser.close")
			PageInst.Call("Schema.getDomains")
			
			Params - An associative array of parameters to be provided to the
			endpoint. For example:
			PageInst.Call("Page.printToPDF", {"scale": 0.5 ; Numeric Value
			, "landscape": Chrome.JSON.True() ; Boolean Value
			, "pageRanges: "1-5, 8, 11-13"}) ; String value
			PageInst.Call("Page.navigate", {"url": "https://autohotkey.com/"})
			
			WaitForResponse - Whether to block until a response is received from
			Chrome, which is necessary to receive a return value, or whether
			to continue on with the script without waiting for a response.
		*/
		Call(DomainAndMethod, Params:="", WaitForResponse:=True)
		{
			if !this.Connected
				throw Exception("Not connected to tab")
			
			; Use a temporary variable for ID in case more calls are made
			; before we receive a response.
			ID := this.ID += 1
			this.ws.Send(Chrome.JSON.Dump({"id": ID
			, "params": Params ? Params : {}
			, "method": DomainAndMethod}))
			
			if !WaitForResponse
				return
			
			; Wait for the response
			this.responses[ID] := False
			while !this.responses[ID]
				Sleep, 50
			
			; Get the response, check if it's an error
			response := this.responses.Delete(ID)
			if (response.error)
				throw Exception("Chrome indicated error in response", -1, Chrome.JSON.Dump(response.error))
			
			return response.result
		}
		
		/*
			Run some JavaScript on the page. For example:
			
			PageInst.Evaluate("alert(""I can't believe it's not IE!"");")
			PageInst.Evaluate("document.getElementsByTagName('button')[0].click();")
		*/
		Evaluate(JS)
		{
			response := this.Call("Runtime.evaluate",
			( LTrim Join
			{
				"expression": JS,
				"objectGroup": "console",
				"includeCommandLineAPI": Chrome.JSON.True,
				"silent": Chrome.JSON.False,
				"returnByValue": Chrome.JSON.False,
				"userGesture": Chrome.JSON.True,
				"awaitPromise": Chrome.JSON.False
			}
			))
			
			if (response.exceptionDetails)
				throw Exception(response.result.description, -1
			, Chrome.JSON.Dump({"Code": JS
			, "exceptionDetails": response.exceptionDetails}))
			
			return response.result
		}
		
		/*
			Waits for the page's readyState to match the DesiredState.
			
			DesiredState - The state to wait for the page's ReadyState to match
			Interval     - How often it should check whether the state matches
		*/
		WaitForLoad(DesiredState:="complete", Interval:=100)
		{
			while this.Evaluate("document.readyState").value != DesiredState
				Sleep, Interval
		}
		
		/*
			Internal function triggered when the script receives a message on
			the WebSocket connected to the page.
		*/
		Event(EventName, Event)
		{
			; If it was called from the WebSocket adjust the class context
			if this.Parent
				this := this.Parent
			
			if (EventName == "Error")
			{
				throw Exception("Error: " Event.code)
			}
			else if (EventName == "Open")
			{
				this.Connected := True
				BoundKeepAlive := this.BoundKeepAlive
				SetTimer, %BoundKeepAlive%, 15000
			}
			else if (EventName == "Message")
			{
				data := Chrome.JSON.Load(Event.data)
				
				; Run the callback routine
				fnCallback := this.fnCallback
				if (newData := %fnCallback%(data))
					data := newData
				
				if this.responses.HasKey(data.ID)
					this.responses[data.ID] := data
			}
			else if (EventName == "Close")
			{
				this.Disconnect()
				fnClose := this.fnClose
				%fnClose%(this)
			}
		}
		
		/*
			Disconnect from the page's debug interface, allowing the instance
			to be garbage collected.
			
			This method should always be called when you are finished with a
			page or else your script will leak memory.
		*/
		Disconnect()
		{
			if !this.Connected
				return
			
			this.Connected := False
			this.ws.Delete("Parent")
			this.ws.Disconnect()
			
			BoundKeepAlive := this.BoundKeepAlive
			SetTimer, %BoundKeepAlive%, Delete
			this.Delete("BoundKeepAlive")
		}
		
		
		class WebSocket {
			
			; The primary HINTERNET handle to the websocket connection
			; This field should not be set externally.
			Ptr := 0
			
			; Whether the websocket is operating in Synchronous or Asynchronous mode.
			; This field should not be set externally.
			async := 0
			
			; The readiness state of the websocket.
			; This field should not be set externally.
			readyState := 0
			
			; The URL this websocket is connected to
			; This field should not be set externally.
			url := ""
			
			; Internal array of HINTERNET handles
			HINTERNETs := []
			
			; Internal buffer used to receive incoming data
			cache := "" ; Access ONLY by ObjGetAddress
			cacheSize := 8192
			
			; Internal buffer used to hold data fragments for multi-packet messages
			recData := ""
			recDataSize := 0
			
			_LastError(Err := -1)
			{
				static module := DllCall("GetModuleHandle", "Str", "winhttp", "Ptr")
				Err := Err < 0 ? A_LastError : Err
				hMem := ""
				DllCall("Kernel32.dll\FormatMessage"
				, "Int", 0x1100 ; [in]           DWORD   dwFlags
				, "Ptr", module ; [in, optional] LPCVOID lpSource
				, "Int", Err    ; [in]           DWORD   dwMessageId
				, "Int", 0      ; [in]           DWORD   dwLanguageId
				, "Ptr*", hMem  ; [out]          LPTSTR  lpBuffer
				, "Int", 0      ; [in]           DWORD   nSize
				, "Ptr", 0      ; [in, optional] va_list *Arguments
				, "UInt") ; DWORD
				return StrGet(hMem), DllCall("Kernel32.dll\LocalFree", "Ptr", hMem, "Ptr")
			}
			
			; Internal function used to load the mcode event filter
			_StatusSyncCallback()
			{
				if this.pCode
					return this.pCode
				b64 := (A_PtrSize == 4)
				? "i1QkDIPsDIH6AAAIAHQIgfoAAAAEdTWLTCQUiwGJBCSLRCQQiUQkBItEJByJRCQIM8CB+gAACAAPlMBQjUQkBFD/cQyLQQj/cQT/0IPEDMIUAA=="
				: "SIPsSEyL0kGB+AAACAB0CUGB+AAAAAR1MEiLAotSGEyJTCQwRTPJQYH4AAAIAEiJTCQoSYtKCEyNRCQgQQ+UwUiJRCQgQf9SEEiDxEjD"
				if !DllCall("crypt32\CryptStringToBinary", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", s := 0, "Ptr", 0, "Ptr", 0)
					throw Exception("failed to parse b64 to binary")
				ObjSetCapacity(this, "code", s)
				this.pCode := ObjGetAddress(this, "code")
				if !DllCall("crypt32\CryptStringToBinary", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", this.pCode, "UInt*", s, "Ptr", 0, "Ptr", 0) &&
					throw Exception("failed to convert b64 to binary")
				if !DllCall("VirtualProtect", "Ptr", this.pCode, "UInt", s, "UInt", 0x40, "UInt*", 0)
					throw Exception("failed to mark memory as executable")
				return this.pCode
				/* c++ source
					struct __CONTEXT {
						void *obj;
						HWND hwnd;
						decltype(&SendMessageW) pSendMessage;
						UINT msg;
					};
					void __stdcall WinhttpStatusCallback(
					void *hInternet,
					DWORD_PTR dwContext,
					DWORD dwInternetStatus,
					void *lpvStatusInformation,
					DWORD dwStatusInformationLength) {
						if (dwInternetStatus == 0x80000 || dwInternetStatus == 0x4000000) {
							__CONTEXT *context = (__CONTEXT *)dwContext;
							void *param[3] = { context->obj,hInternet,lpvStatusInformation };
							context->pSendMessage(context->hwnd, context->msg, (WPARAM)param, dwInternetStatus == 0x80000);
						}
					}
				*/
			}
			
			; Internal event dispatcher for compatibility with the legacy interface
			_Event(name, event)
			{
				this["On" name](event)
			}
			
			; Reconnect
			reconnect()
			{
				this.connect()
			}
			
			pRecData[] {
				get {
					return ObjGetAddress(this, "recData")
				}
			}
			
			__New(url, events := 0, async := true, headers := "")
			{
				this.url := url
				
				this.HINTERNETs := []
				
				; Force async to boolean
				this.async := async := !!async
				
				; Iniitalize the Cache
				ObjSetCapacity(this, "cache", this.cacheSize)
				this.pCache := ObjGetAddress(this, "cache")
				
				; Iniitalize the RecData
				; this.pRecData := ObjGetAddress(this, "recData")
				
				; Find the script's built-in window for message targeting
				dhw := A_DetectHiddenWindows
				DetectHiddenWindows, On
				this.hWnd := WinExist("ahk_class AutoHotkey ahk_pid " DllCall("GetCurrentProcessId"))
				DetectHiddenWindows, %dhw%
				
				; Parse the url
				if !RegExMatch(url, "Oi)^((?<SCHEME>wss?)://)?((?<USERNAME>[^:]+):(?<PASSWORD>.+)@)?(?<HOST>[^/:]+)(:(?<PORT>\d+))?(?<PATH>/.*)?$", m)
					throw Exception("Invalid websocket url")
				this.m := m
				
				; Open a new HTTP API instance
				if !(hSession := DllCall("Winhttp\WinHttpOpen"
					, "Ptr", 0  ; [in, optional]        LPCWSTR pszAgentW
					, "UInt", 0 ; [in]                  DWORD   dwAccessType
					, "Ptr", 0  ; [in]                  LPCWSTR pszProxyW
					, "Ptr", 0  ; [in]                  LPCWSTR pszProxyBypassW
					, "UInt", async * 0x10000000 ; [in] DWORD   dwFlags
					, "Ptr")) ; HINTERNET
					throw Exception("WinHttpOpen failed: " this._LastError())
				this.HINTERNETs.Push(hSession)
				
				; Connect the HTTP API to the remote host
				port := m.PORT ? (m.PORT + 0) : (m.SCHEME = "ws") ? 80 : 443
				if !(this.hConnect := DllCall("Winhttp\WinHttpConnect"
					, "Ptr", hSession ; [in] HINTERNET     hSession
					, "WStr", m.HOST  ; [in] LPCWSTR       pswzServerName
					, "UShort", port  ; [in] INTERNET_PORT nServerPort
					, "UInt", 0       ; [in] DWORD         dwReserved
					, "Ptr")) ; HINTERNET
					throw Exception("WinHttpConnect failed: " this._LastError())
				this.HINTERNETs.Push(this.hConnect)
				
				; Translate headers from array to string
				if IsObject(headers)
				{
					s := ""
					for k, v in headers
						s .= "`r`n" k ": " v
					headers := LTrim(s, "`r`n")
				}
				this.headers := headers
				
				; Set any event handlers from events parameter
				for k, v in IsObject(events) ? events : []
					if (k ~= "i)^(data|message|close)$")
						this["on" k] := v
				
				; Set up a handler for messages from the StatusSyncCallback mcode
				this.wm_ahkmsg := DllCall("RegisterWindowMessage", "Str", "AHK_WEBSOCKET_STATUSCHANGE_" &this, "UInt")
				OnMessage(this.wm_ahkmsg, this.WEBSOCKET_STATUSCHANGE.Bind({})) ; TODO: Proper binding
				
				; Connect on start
				this.connect()
			}
			
			connect() {
				; Collect pointer to SendMessageW routine for the StatusSyncCallback mcode
				static pSendMessageW := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "User32", "Ptr"), "AStr", "SendMessageW", "Ptr")
				
				; If the HTTP connection is closed, we cannot request a websocket
				if !this.HINTERNETs.Length()
					throw Exception("The connection is closed")
				
				; Shutdown any existing websocket connection
				this.shutdown()
				
				; Free any HINTERNET handles from previous websocket connections
				while (this.HINTERNETs.Length() > 2)
					DllCall("Winhttp\WinHttpCloseHandle", "Ptr", this.HINTERNETs.Pop())
				
				; Open an HTTP Request for the target path
				dwFlags := (this.m.SCHEME = "wss") ? 0x800000 : 0
				if !(hRequest := DllCall("Winhttp\WinHttpOpenRequest"
					, "Ptr", this.hConnect ; [in] HINTERNET hConnect,
					, "WStr", "GET"        ; [in] LPCWSTR   pwszVerb,
					, "WStr", this.m.PATH  ; [in] LPCWSTR   pwszObjectName,
					, "Ptr", 0             ; [in] LPCWSTR   pwszVersion,
					, "Ptr", 0             ; [in] LPCWSTR   pwszReferrer,
					, "Ptr", 0             ; [in] LPCWSTR   *ppwszAcceptTypes,
					, "UInt", dwFlags      ; [in] DWORD     dwFlags
					, "Ptr")) ; HINTERNET
					throw Exception("WinHttpOpenRequest failed: " this._LastError())
				this.HINTERNETs.Push(hRequest)
				
				if this.headers
				{
					if ! DllCall("Winhttp\WinHttpAddRequestHeaders"
						, "Ptr", hRequest      ; [in] HINTERNET hRequest,
						, "WStr", this.headers ; [in] LPCWSTR   lpszHeaders,
						, "UInt", -1           ; [in] DWORD     dwHeadersLength,
						, "UInt", 0x20000000   ; [in] DWORD     dwModifiers
						, "Int") ; BOOL
						throw Exception("WinHttpAddRequestHeaders failed: " this._LastError())
				}
				
				; Make the HTTP Request
				status := "00000"
				if (!DllCall("Winhttp\WinHttpSetOption", "Ptr", hRequest, "UInt", 114, "Ptr", 0, "UInt", 0, "Int")
					|| !DllCall("Winhttp\WinHttpSendRequest", "Ptr", hRequest, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt", 0, "UPtr", 0, "Int")
					|| !DllCall("Winhttp\WinHttpReceiveResponse", "Ptr", hRequest, "Ptr", 0)
					|| !DllCall("Winhttp\WinHttpQueryHeaders", "Ptr", hRequest, "UInt", 19, "Ptr", 0, "WStr", status, "UInt*", 10, "Ptr", 0, "Int")
					|| status != "101")
					throw Exception("Invalid status: " status)
				
				; Upgrade the HTTP Request to a Websocket connection
				if !(this.Ptr := DllCall("Winhttp\WinHttpWebSocketCompleteUpgrade", "Ptr", hRequest, "Ptr", 0))
					throw Exception("WinHttpWebSocketCompleteUpgrade failed: " this._LastError())
				
				; Close the HTTP Request, save the Websocket connection
				DllCall("Winhttp\WinHttpCloseHandle", "Ptr", this.HINTERNETs.Pop())
				this.HINTERNETs.Push(this.Ptr)
				this.readyState := 1
				
				; Configure asynchronous callbacks
				if (this.async)
				{
					; Populate context struct for the mcode to reference
					ObjSetCapacity(this, "__context", 4 * A_PtrSize)
					pCtx := ObjGetAddress(this, "__context")
					NumPut(&this         , pCtx + A_PtrSize * 0, "Ptr")
					NumPut(this.hWnd     , pCtx + A_PtrSize * 1, "Ptr")
					NumPut(pSendMessageW , pCtx + A_PtrSize * 2, "Ptr")
					NumPut(this.wm_ahkmsg, pCtx + A_PtrSize * 3, "UInt")
					
					if !DllCall("Winhttp\WinHttpSetOption"
						, "Ptr", this.Ptr   ; [in] HINTERNET hInternet
						, "UInt", 45        ; [in] DWORD     dwOption
						, "Ptr*", pCtx      ; [in] LPVOID    lpBuffer
						, "UInt", A_PtrSize ; [in] DWORD     dwBufferLength
						, "Int") ; BOOL
						throw Exception("WinHttpSetOption failed: " this._LastError())
					
					StatusCallback := this._StatusSyncCallback()
					if (-1 == DllCall("Winhttp\WinHttpSetStatusCallback"
						, "Ptr", this.Ptr       ; [in] HINTERNET               hInternet,
						, "Ptr", StatusCallback ; [in] WINHTTP_STATUS_CALLBACK lpfnInternetCallback,
						, "UInt", 0x80000       ; [in] DWORD                   dwNotificationFlags,
						, "UPtr", 0             ; [in] DWORD_PTR               dwReserved
						, "Ptr")) ; WINHTTP_STATUS_CALLBACK
						throw Exception("WinHttpSetStatusCallback failed: " this._LastError())
					
					; Make the initial request for data to receive an asynchronous response for
					if (ret := DllCall("Winhttp\WinHttpWebSocketReceive"
						, "Ptr", this.Ptr        ; [in]  HINTERNET                      hWebSocket,
						, "Ptr", this.pCache     ; [out] PVOID                          pvBuffer,
						, "UInt", this.cacheSize ; [in]  DWORD                          dwBufferLength,
						, "UInt*", 0             ; [out] DWORD                          *pdwBytesRead,
						, "UInt*", 0             ; [out] WINHTTP_WEB_SOCKET_BUFFER_TYPE *peBufferType
						, "UInt")) ; DWORD
						throw Exception("WinHttpWebSocketReceive failed: " ret)
				}
				
				; Fire the open event
				this._Event("Open", {})
			}
			
			WEBSOCKET_STATUSCHANGE(wp, lp, msg, hwnd) {
				if !lp {
					this.readyState := 3
					return
				}
				
				; Grab `this` from the provided context struct
				this := Object(NumGet(wp + A_PtrSize * 0, "Ptr"))
				
				; Don't process data when the websocket isn't ready
				if (this.readyState != 1)
					return
				
				; Grab the rest of the context data
				hInternet :=            NumGet(wp + A_PtrSize * 1, "Ptr")
				lpvStatusInformation := NumGet(wp + A_PtrSize * 2, "Ptr")
				dwBytesTransferred :=   NumGet(lpvStatusInformation + 0, "UInt")
				eBufferType :=          NumGet(lpvStatusInformation + 4, "UInt")
				
				; Mark the current size of the received data buffer for use as an offset
				; for the start of any newly provided data
				offset := this.recDataSize
				
				if (eBufferType > 3)
				{
					closeStatus := this.QueryCloseStatus()
					this.shutdown()
					this.onClose(closeStatus.status, closeStatus.reason)
					return
				}
				
				try {
					if (eBufferType == 0) ; BINARY
					{
						if offset ; Continued from a fragment
						{
							VarSetCapacity(data, offset + dwBytesTransferred)
							
							; Copy data from the fragment buffer
							DllCall("RtlMoveMemory"
							, "Ptr", &data
							, "Ptr", this.pRecData
							, "UInt", this.recDataSize)
							
							; Copy data from the new data cache
							DllCall("RtlMoveMemory"
							, "Ptr", &data + offset
							, "Ptr", this.pCache
							, "UInt", dwBytesTransferred)
							
							; Clear fragment buffer
							this.recDataSize := 0
							
							this.onData(data, offset + dwBytesTransferred)
						}
						else ; No prior fragment
						{
							; Copy data from the new data cache
							VarSetCapacity(data, dwBytesTransferred)
							DllCall("RtlMoveMemory"
							, "Ptr", &data
							, "Ptr", this.pCache
							, "UInt", dwBytesTransferred)
							
							this.onData(data, dwBytesTransferred)
						}
					}
					else if (eBufferType == 2) ; UTF8
					{
						if offset
						{
							; Continued from a fragment
							this.recDataSize += dwBytesTransferred
							ObjSetCapacity(this, "recData", this.recDataSize)
							
							DllCall("RtlMoveMemory"
							, "Ptr", this.pRecData + offset
							, "Ptr", this.pCache
							, "UInt", dwBytesTransferred)
							
							msg := StrGet(this.pRecData, "utf-8")
							this.recDataSize := 0
						}
						else ; No prior fragment
							msg := StrGet(this.pCache, dwBytesTransferred, "utf-8")
						
						this._Event("Message", {data: msg})
					}
					else if (eBufferType == 1 || eBufferType == 3) ; BINARY_FRAGMENT, UTF8_FRAGMENT
					{
						; Add the fragment to the received data buffer
						this.recDataSize += dwBytesTransferred
						ObjSetCapacity(this, "recData", this.recDataSize)
						DllCall("RtlMoveMemory"
						, "Ptr", this.pRecData + offset
						, "Ptr", this.pCache
						, "UInt", dwBytesTransferred)
					}
				}
				finally
				{
					askForMoreData := this.askForMoreData.Bind(this, hInternet)
					SetTimer, %askForMoreData%, -1
				}
			}
			
			askForMoreData(hInternet)
			{
				; Original implementation used a while loop here, but in my experience
				; that causes lost messages
				ret := DllCall("Winhttp\WinHttpWebSocketReceive"
				, "Ptr", hInternet       ; [in]  HINTERNET hWebSocket,
				, "Ptr", this.pCache     ; [out] PVOID     pvBuffer,
				, "UInt", this.cacheSize ; [in]  DWORD     dwBufferLength,
				, "UInt*", 0             ; [out] DWORD     *pdwBytesRead,
				, "UInt*", 0             ; [out]           *peBufferType
				, "UInt") ; DWORD
				if (ret && ret != 4317) ; TODO: what is this constant?
					this._Error({code: ret})
			}
			
			__Delete()
			{
				this.shutdown()
				; Free all active HINTERNETs
				while (this.HINTERNETs.Length())
					DllCall("Winhttp\WinHttpCloseHandle", "Ptr", this.HINTERNETs.Pop())
			}
			
			; Default error handler
			_Error(err)
			{
				if (err.code != 12030) {
					this._Event("Error", {code: ret})
					return
				}
				if (this.readyState == 3)
					return
				this.readyState := 3
				try this._Event("Close", {status: 1006, reason: ""})
			}
			
			queryCloseStatus() {
				usStatus := 0
				VarSetCapacity(vReason, 123, 0)
				if (!DllCall("Winhttp\WinHttpWebSocketQueryCloseStatus"
					, "Ptr", this.Ptr     ; [in]  HINTERNET hWebSocket,
					, "UShort*", usStatus ; [out] USHORT    *pusStatus,
					, "Ptr", &vReason     ; [out] PVOID     pvReason,
					, "UInt", 123         ; [in]  DWORD     dwReasonLength,
					, "UInt*", len        ; [out] DWORD     *pdwReasonLengthConsumed
					, "UInt")) ; DWORD
					return { status: usStatus, reason: StrGet(&vReason, len, "utf-8") }
				else if (this.readyState > 1)
					return { status: 1006, reason: "" }
			}
			
			; eBufferType BINARY_MESSAGE = 0, BINARY_FRAGMENT = 1, UTF8_MESSAGE = 2, UTF8_FRAGMENT = 3
			sendRaw(eBufferType, pvBuffer, dwBufferLength) {
				if (this.readyState != 1)
					throw Exception("websocket is disconnected")
				if (ret := DllCall("Winhttp\WinHttpWebSocketSend"
					, "Ptr", this.Ptr        ; [in] HINTERNET                      hWebSocket
					, "UInt", eBufferType    ; [in] WINHTTP_WEB_SOCKET_BUFFER_TYPE eBufferType
					, "Ptr", pvBuffer        ; [in] PVOID                          pvBuffer
					, "UInt", dwBufferLength ; [in] DWORD                          dwBufferLength
					, "UInt")) ; DWORD
					this._Error({code: ret})
			}
			
			; sends a utf-8 string to the server
			send(str)
			{
				if (size := StrPut(str, "utf-8") - 1)
				{
					VarSetCapacity(buf, size, 0)
					StrPut(str, &buf, "utf-8")
					this.sendRaw(2, &buf, size)
				}
				else
					this.sendRaw(2, 0, 0)
			}
			
			receive()
			{
				if (this.async)
					throw Exception("Used only in synchronous mode")
				if (this.readyState != 1)
					throw Exception("websocket is disconnected")
				
				rec := {data: "", size: 0, ptr: 0}
				
				offset := 0
				while (!ret := DllCall("Winhttp\WinHttpWebSocketReceive"
					, "Ptr", this.Ptr           ; [in]  HINTERNET                      hWebSocket
					, "Ptr", this.pCache        ; [out] PVOID                          pvBuffer
					, "UInt", this.cacheSize    ; [in]  DWORD                          dwBufferLength
					, "UInt*", dwBytesRead := 0 ; [out] DWORD                          *pdwBytesRead
					, "UInt*", eBufferType := 0 ; [out] WINHTTP_WEB_SOCKET_BUFFER_TYPE *peBufferType
					, "UInt")) ; DWORD
				{
					switch eBufferType
					{
						case 0:
						if offset
						{
							rec.size += dwBytesRead
							ObjSetCapacity(rec, "data", rec.size)
							ptr := ObjGetAddress(rec, "data")
							DllCall("RtlMoveMemory", "Ptr", ptr + offset, "Ptr", this.pCache, "UInt", dwBytesRead)
						}
						else
						{
							recSize := dwBytesRead
							ObjSetCapacity(rec, "data", rec.size)
							ptr := ObjGetAddress(rec, "data")
							DllCall("RtlMoveMemory", "Ptr", ptr, "Ptr", this.pCache, "UInt", dwBytesRead)
						}
						return rec
						case 1, 3:
						rec.size += dwBytesRead
						ObjSetCapacity(rec, "data", rec.size)
						ptr := ObjGetAddress(rec, "data")
						DllCall("RtlMoveMemory", "Ptr", rec + offset, "Ptr", this.pCache, "UInt", dwBytesRead)
						offset += dwBytesRead
						case 2:
						if (offset) {
							rec.size += dwBytesRead
							ObjSetCapacity(rec, "data", rec.size)
							ptr := ObjGetAddress(rec, "data")
							DllCall("RtlMoveMemory", "Ptr", ptr + offset, "Ptr", this.pCache, "UInt", dwBytesRead)
							return StrGet(ptr, "utf-8")
						}
						return StrGet(this.pCache, dwBytesRead, "utf-8")
						default:
						rea := this.queryCloseStatus()
						this.shutdown()
						try this._Event("Close", {status: rea.status, reason: rea.reason})
							return
					}
				}
				if (ret != 4317)
					this._Error({code: ret})
			}
			
			; sends a close frame to the server to close the send channel, but leaves the receive channel open.
			shutdown() {
				if (this.readyState != 1)
					return
				this.readyState := 2
				DllCall("Winhttp\WinHttpWebSocketShutdown", "Ptr", this.Ptr, "UShort", 1000, "Ptr", 0, "UInt", 0)
				this.readyState := 3
			}
		}
	}
	
	Jxon_Load(p*)
	{
		return this.JSON.Load(p*)
	}
	
	Jxon_Dump(p*)
	{
		return this.JSON.Dump(p*)
	}
	
	Jxon_True()
	{
		return this.JSON.True()
	}
	
	Jxon_False()
	{
		return this.JSON.False()
	}
	
	Jxon_Null()
	{
		return this.JSON.Null()
	}
	
	;
	; cJson.ahk 0.5.1-git-built
	; Copyright (c) 2021 Philip Taylor (known also as GeekDude, G33kDude)
	; https://github.com/G33kDude/cJson.ahk
	;
	; MIT License
	;
	; Permission is hereby granted, free of charge, to any person obtaining a copy
	; of this software and associated documentation files (the "Software"), to deal
	; in the Software without restriction, including without limitation the rights
	; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	; copies of the Software, and to permit persons to whom the Software is
	; furnished to do so, subject to the following conditions:
	;
	; The above copyright notice and this permission notice shall be included in all
	; copies or substantial portions of the Software.
	;
	; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	; SOFTWARE.
	;
	
	class JSON
	{
		static version := "0.5.1-git-built"
		
		BoolsAsInts[]
		{
			get
			{
				this._init()
				return NumGet(this.lib.bBoolsAsInts, "Int")
			}
			
			set
			{
				this._init()
				NumPut(value, this.lib.bBoolsAsInts, "Int")
				return value
			}
		}
		
		NullsAsStrings[]
		{
			get
			{
				this._init()
				return NumGet(this.lib.bNullsAsStrings, "Int")
			}
			
			set
			{
				this._init()
				NumPut(value, this.lib.bNullsAsStrings, "Int")
				return value
			}
		}
		
		EmptyObjectsAsArrays[]
		{
			get
			{
				this._init()
				return NumGet(this.lib.bEmptyObjectsAsArrays, "Int")
			}
			
			set
			{
				this._init()
				NumPut(value, this.lib.bEmptyObjectsAsArrays, "Int")
				return value
			}
		}
		
		EscapeUnicode[]
		{
			get
			{
				this._init()
				return NumGet(this.lib.bEscapeUnicode, "Int")
			}
			
			set
			{
				this._init()
				NumPut(value, this.lib.bEscapeUnicode, "Int")
				return value
			}
		}
		
		_init()
		{
			if (this.lib)
				return
			this.lib := this._LoadLib()
			
			; Populate globals
			NumPut(&this.True, this.lib.objTrue, "UPtr")
			NumPut(&this.False, this.lib.objFalse, "UPtr")
			NumPut(&this.Null, this.lib.objNull, "UPtr")
			
			this.fnGetObj := Func("Object")
			NumPut(&this.fnGetObj, this.lib.fnGetObj, "UPtr")
			
			this.fnCastString := Func("Format").Bind("{}")
			NumPut(&this.fnCastString, this.lib.fnCastString, "UPtr")
		}
		
		_LoadLib32Bit() {
			static CodeBase64 := ""
			. "FrYcAQADAAFwATBVieUQU4HstABIi0UUAIiFdP///4tFQAiLEKEkFwBIACA5wg+EpABwx0UC9AHU6ziDfQwAgHQhi0X0BTAAQAAPthiLRQyLAACN"
			. "SAKLVQyJCgBmD77TZokQ65ANi0UQACpQAQAOYIkQg0X0ABAFYgAQhMB1uQBjmYlFEKCJVaQBIUQkCBMARgAGBI0AEwQk6FBmHAAAAmkUC17HKAAi"
			. "AAxcuAGX6cNABwAAxkXzAMQIAItAEIXAdQwPCLYFBAAZiEXz6xpXARVQAKkBGznCdUJHgBQBx0XsgmgpAQIODItF7MHgBEAB0IlFsIsAAUAACItV"
			. "7IPCATkQ0A+UwIAhg0XsgAGAffMAdAuEIlBF7HzGglAkAgsHxLtbASYFu3uCpIlZJIkYjFiAvYGyAHQQUMdF6Auq6AVBHSiq6AAEhRgCqsdF5FkC"
			. "hqkFgUGDauSEaqyAg33kAA+OqYAPDRNWLA1WhSlSx0XgdYsp4Kop4AACRQyCKesKJ1MgIFUgZcdF3CFCIFTHRdiLItgFOkSoItgAAkUMgiKDRQLc"
			. "gAQYO0XcfaQED7aAefABhMAPDISfQMbCeRg5ReTEfXxkootFrMCNgLVQmIlVnI21mIG1j2oZRF8XDxPpgTjKE+kWykIEgCEcgCEPjZ9FwuHUC0DU"
			. "BUYoQNQPAAIlBuRwZBaQiVWUpW0WkGEW2xhYcSvqCwTrHMMJi1UQiVQj4AjgBFQkBIEIihodlQg6rSh/Q4ctDIP4WAF1HkEBLg4kwBbpDJwCASgD"
			. "BQYPhV41wjqsgJsoICAAgVXHxEXQyynQBU/fKcYpTtAAASUGwinpKiQOEBShIEYMzEsMzAVUu18MRgzMAAElBkMMx6YYi0G0QwzISwzIBVpfDF1G"
			. "DMgAASUGQwxkQgwYQI1IAQ+2lUPCrKCLAIlMJKEsDI8twLf5///pL+QSgS1YBXUgQgZPBYDhMgQRSAUCdWlAAY1VgKklBP4UwVzEIho3IhoAIItV"
			. "iItFxAEQwI0cAioaD7cTCREaxAEFBgHQD7dEAGbAwbfpkKJnwLELJcAFXx8l5grAAAFnJQamZy4cqhV/10YK5AMAAePJ5A+MSPr/ov9kng+EteIV"
			. "vOsV9rw/r4gLvAABJQYExKLld3FUEX+IBbR/VI8FhgW0F4AAFQN0VLggAbg7RagYfKRacV1TcX1fcYNdcZIJi138ycORGrMCALCJV1bQiZNRDBAU"
			. "IhRxAMdACNEBx0C2DDIMYAQIYQSgIQhxQYPAAEEfg/ggdOXYAIgKdNfYAA10ydgACAl0u9gAew+FcqNiPGgFx0WgMgdFwZCVYACoYwCsYQChqPAI"
			. "IbAuQBiLFaEAx0QkJCDiAUQkYIwAAAiNTZCgMxiNTaD1YAAUUAEQgZdwAPILcAAH4wwgV3EAiRQk/9CQg+wkiyBjRbDfDQ/fDd8N3w3XAH0PhFQr"
			. "5G0SAYXwbkMJAYP4ECJ0CrhAKP/p5HEQCo1FgNFg4QfALWmA/v//hcB0F/MBfsTwAf8J/wn/Cf8J1QA6ncUHZ88FcmmUCN/9kghVxAI6wgKIYzgI"
			. "YwKw/WECjIABTxRPCk8KTwrXAEgsdRIqBelUcBGQs1kWhQmhC18MgCwJ4jCgVbCJUAgDrHl1AmHzA1sPhfBFGTYohV5woUGxInK6kwB4lgB8Z5QA"
			. "/yj8KI1gkAIiKY1PEQVfKV8pVimFaBEDRf60sKbxAq8VrxWvFa8V1wCwXQ+EtnSP9imlA0DJ2B/h+9kfPAr1AcCL6uRjArRhAuZQFS8KLwo3Lwov"
			. "CtkfFioFYVzpAcuACBkgXcUJnwkfIBcgGrQWIHd1AkQ4D4VjpgPvNWB4ReCSA+CQA+GjBAgA6e8FS/RutAfCIzsFXA+Fqp1NKQfFUXvggAGJVeDi"
			. "ajsuros5BsAE2wJc3AJd2wKqL9sCL9wCL9sCYtsCqgjcAgHbAmbbAgzcAqrT201u2wIK3AKl2wKqctsCDdwCd9sCdNsCCzEe2QJJ2wJ1D4UR300+"
			. "4AOAA7FlIs/podcwATMAA4DcicLhATobL37iMNgAOX8iwwKRAlMBIAHQg+gwhQPpgMu3AAAAAItFCIsAAA+3AGaD+EB+Ai0IaEZ/H4tF4AkALInC"
			. "BVQB0IPoAjcBOOBmiRDrRVUIsGAKdGYTdFcGdApEuP8AAOmSBgR/jQRQAgAHiRCDRdwAAYN93AMPjhaBAB+DReAC6yYDKqJnBCoQjUoCKggASaCN"
			. "SAKJTQBmEgBSAQh9Ig+F//z//yCLRQyLSAEmKcgBAXcMi0AIg+gEsQEp4GbHBfgFPLgACBgA6QKFRwMkLXQkQYgGLw+OsQOKDzkID4+fgAjHRdgB"
			. "FYInDIArFIEDx0AIMYEnx0AMAQOJKHUUj4AWAWiKPogQMHUjEyCJhRXpjgspMH51CUlQf2frRwF2UIF3awDaCmvIAAHZuwIKgBn34wHRicoAi00I"
			. "iwmNcQIAi10IiTMPtzEAD7/OicvB+x8AAcgR2oPA0IMA0v+LTQyJQQhIiVEMyT5+GgkZfoKdRXDQBAAAkIgGMC4PhaVNLIYjZg8EbsDAAMpmD2LB"
			. "IGYP1oVQQBDfrbNBAYAI3VjAakFQBQBUAtQBVOtCi1XUiQDQweACAdABwAiJRdRDFUgCi1UICIkKwBuYg+gwKImFTMAP20MBRdSE3vmBEkAI3sGF"
			. "FBXIMA7KMKJIA2V0EuFIA0UPhVUAIA0xAweoFHUxCTTQwADaADSK0wA0lRU0xkXTS4FqE0AEAcoX60DMBggrvHURhgzQiE0yxGJEwqKCzEGM6yeL"
			. "VcyHToLDUU4B2IlFzLgKEL3HRcjBMMdFxCFCChOLVcioMciDBEXEQBjEO0XMfIDlgH3TAHQTQy8I20XIozBYCOsRrUcCyUYi5SgrJHRYIE0A2JmJ"
			. "3w+v+IkA1g+v8QH+9+GYjQwWYVUkUesdxgY0BXVmCthwCkQuAwAJA3oxAmpldA+FqwUiGsAiGjeLRcAFAE8XAAAPtgBmiA++0CYFOcJ0ZCpi8O1A"
			. "g0XAoB7GBoRAwHW6D7YFwQmEeMB0G6UPQ3iiJ0N464IsQwMJAIsVKEAHIaABiVAIoUIBAIsEQASjAokUJP/Q6IPsBIMXdGUPhKqFF6K8hRe8BVSa"
			. "FzOPF768gBfGBpoX6I+JFyCHFy9CAYMXQQGLF7erlG4PDIWggheiA+s0i0UouAVakxcHghfred0sF7ggF2YGIBe9IBehE9UgFxbDEwjAEyzGE4kW"
			. "PiSHFkIBgxZBAYoW6wUBQg+NZfRbXl9dMMOQkJChAgkAIlUAbmtub3duX08AYmplY3RfAA0KCgAMIqUBdHJ1ZQAAZmFsc2UAbgh1bGzHBVZhbHUA"
			. "ZV8AMDEyMzQANTY3ODlBQkMAREVGAFWJ5VNAg+xUx0X05ryLAEAUjVX0iVQkIBTHRCQQojBEJKIMQUmNVQzAAgjAAQ+ArqAFYHmjFxjHReSpAgVF"
			. "6MMA7MMA8IMKcBCJReRgAmPUIgwYqItV9MAIIKQLHHQAghhxAI1N5IlMwwffYQbBB+QBIiEQCASXB/Bx0hADHgl18CMQMFHxBUAIi1UQi1JFAgTE"
			. "62hmAgN1XGEC0lMSu7AWf7lBBTnDGSjRfBWGAT0gAYCJQNCD2P99LmAbjTRV4HEPiXAPsSAEJATooQAChcB0EYsETeBGA4kBiVEEYJCLXfzJgBtw"
			. "FYNA7Fhmx0Xugx9FCvAgFhQBEE0Mus0AzMzMicj34sGE6gP2TCnBicoQB0DAMINt9AHhgvRgZolURcawA+IC9wLikALoA4lFDIOAfQwAdbmNVaAB"
			. "UPQBwAGQAhCACQiDYhHDCSj+//+QQAihsx1gx0X4AjEapEgBwApF+MHgBAHQCIlF2AEBQBg5RbD4D41E8BkAC85RAgLY8QxF9MZF8wBAg330AHkH"
			. "kAABGPdd9FAcQwz0umcoZmZmQAzqcAn4AiESfCnYicL/DINtKuzyDOzxDKaeA8H5UB+JyimgCPSBBnWApYB98wB0DkEDQSEDx0RFpi1wJ6aHwADA"
			. "DmAC0MZF65AlIeImi0XkjeGO0AGI0A+38GnkjQzBFiQByIM8dVgKAgBmUIXAdRklAQwmAQbZEAUB69CjvAJ0EIe8AgB0B4NF5AHrh4CQgH3rAA+E"
			. "YWmZ4R9V2PCb0S3pyiQuZEAcIRWMo+IAwxTUqMZF44AL3IML3IIF+tSEC9yPCwgChQsjAYoLvuOCC7wCgQu8AoEL3IMLEOMAdA9KC+sYgyRF+LKA"
			. "QBBSC9f9/P//4ki6LL89YgByQ2AjhOgFgQ/dAN1dkC7G2LMBsg7HReBjACIbOI1F6FAnMAGRB6GkOxA940AVoQAdQeF3TCTwGI1N2AVBAm0MQeVI"
			. "fxVBIQs/Cz8LwAExEgAxBPSLAAA6iSBJnwufC58LX58LnwufC58LNjtkwAnmz5IK0jY0CldJfBg1AStMoH1ujUWoaEr2kEAJVA/rN4FDdCCLVQCw"
			. "i0XwAcCNHFVwbQw0mQwxmRNx0Q2XoSFAb/AgEEFv8AEFAzVmJ7fzdT60fdMT7IMAfewAeW2LTeyTj0GPQbgwEAQp0KpOzr6+A6ZBwgV1o+ECwQLB"
			. "QEG+LQDrW88GzwaXX1WvBq8GpYQj6z5CE9AnjVW+1lbovxO/E9myE+gBfAMmFKnpNbMqGhiSBhd6BcCDIgDpZsky35gF6bdT4MTmdcpWogMUrQNc"
			. "AB0JHwbVEwZjHgZRGQZcHwYfBlMfBmgC6QEeBu/TaImxAA+3AGaD+Ah1AFaDfQwAdBSLAEUMiwCNSAKLAFUMiQpmxwBcQADrDYtFEABMUFIBAByJ"
			. "EAKYFw2YYkAA6Z8CAAAKUukqjQIiCAPCDDzCZgBU6T0OYSsJYQo8YW7QAOnbAY0wyYIIhDBCDbwwcgDpeY4wZ4WJMAm8MHQA6ReOMAIFgAgPtgUI"
			. "AAAgAITAdCkGNh92QgyGBX52B7iACQAI6wW4QAEAg+ABVOszCAoYCAoTxAI92KAAdw0NwBdvKTCOCQZ1jQkDGw+3wItVIBCJVCQIAQpUJEAEiQQk"
			. "6G2BHisnwhHAJ8gRi1XADBJmRIkQjRxFCAIEL4WAwA+FOvz//1MhAiJNIZDJw5CQkIBVieVTg+wkgBAAZolF2MdF8G9AFwAAx0X4AT/rAC0Pt0XY"
			. "g+APAInCi0XwAdAPALYAZg++0ItFQPhmiVRF6AEHZgjB6AQBDoNF+AEAg334A37Nx0UU9APBDjOCIRyLRUD0D7dcReiKI4kS2hAybfRAEPQAeSLH"
			. "Al6LXfzCJw=="
			static Code := false
			if ((A_PtrSize * 8) != 32) {
				Throw Exception("_LoadLib32Bit does not support " (A_PtrSize * 8) " bit AHK, please run using 32 bit AHK")
			}
			; MCL standalone loader https://github.com/G33kDude/MCLib.ahk
			; Copyright (c) 2021 G33kDude, CloakerSmoker (CC-BY-4.0)
			; https://creativecommons.org/licenses/by/4.0/
			if (!Code) {
				CompressedSize := VarSetCapacity(DecompressionBuffer, 3955, 0)
				if !DllCall("Crypt32\CryptStringToBinary", "Str", CodeBase64, "UInt", 0, "UInt", 1, "Ptr", &DecompressionBuffer, "UInt*", CompressedSize, "Ptr", 0, "Ptr", 0, "UInt")
					throw Exception("Failed to convert MCLib b64 to binary")
				if !(pCode := DllCall("GlobalAlloc", "UInt", 0, "Ptr", 9164, "Ptr"))
					throw Exception("Failed to reserve MCLib memory")
				DecompressedSize := 0
				if (DllCall("ntdll\RtlDecompressBuffer", "UShort", 0x102, "Ptr", pCode, "UInt", 9164, "Ptr", &DecompressionBuffer, "UInt", CompressedSize, "UInt*", DecompressedSize, "UInt"))
					throw Exception("Error calling RtlDecompressBuffer",, Format("0x{:08x}", r))
				for k, Offset in [41, 74, 124, 236, 415, 465, 582, 632, 721, 771, 978, 1028, 1286, 1313, 1363, 1385, 1412, 1462, 1484, 1511, 1561, 1808, 1858, 1984, 2034, 2073, 2123, 2388, 2399, 3044, 3055, 5379, 5434, 5448, 5493, 5504, 5515, 5568, 5623, 5637, 5682, 5693, 5704, 5757, 5809, 5823, 5841, 5863, 5874, 5885, 7166, 7177, 7352, 7363, 8682, 9021] {
					Old := NumGet(pCode + 0, Offset, "Ptr")
					NumPut(Old + pCode, pCode + 0, Offset, "Ptr")
				}
				OldProtect := 0
				if !DllCall("VirtualProtect", "Ptr", pCode, "Ptr", 9164, "UInt", 0x40, "UInt*", OldProtect, "UInt")
					Throw Exception("Failed to mark MCLib memory as executable")
				Exports := {}
				for ExportName, ExportOffset in {"bBoolsAsInts": 0, "bEmptyObjectsAsArrays": 4, "bEscapeUnicode": 8, "bNullsAsStrings": 12, "dumps": 16, "fnCastString": 2212, "fnGetObj": 2216, "loads": 2220, "objFalse": 5920, "objNull": 5924, "objTrue": 5928} {
					Exports[ExportName] := pCode + ExportOffset
				}
				Code := Exports
			}
			return Code
		}
		_LoadLib64Bit() {
			static CodeBase64 := ""
			. "2rUcAQAbAA34DTxVSIkg5UiB7MAAFEiJAE0QSIlVGEyJAEUgRInIiEUoQEiLRRBIiwAEBQTVHQA+iwBIOcKID4S8AFbHRfwBegDrR0iDfRgAdAAt"
			. "i0X8SJhIjYQV3QAnRA+2BAAzBEUYATCNSAJIiwBVGEiJCmZBD4C+0GaJEOsPABtAIIsAjVABAQiJoBCDRfwBBT+dAD8hAT6EwHWlAn2JRSCgSItN"
			. "IAJDjUUAoEmJyEiJwegsliMAjgJ5GRA0xwAUIgCOMriBV+kvCWAAAMZF+4BlgWxAACBIhcB1DA+2AAXF/v//iEX7JOtwAwxQMAYQOcKEdVuAGAHH"
			. "RfSCeEI1hBAYi0X0AFnBoOAFSAHQAFOwgAuJgAFQEIALg8ABAA0JgJWUwAAqg0X0AUCAffsAdBMBGWNS0AgtfLKDYiyCDwgIQbhbATEGQbh7E4HH"
			. "j2xEiQ9sgH0oQAB0ZMdF8Axk8GkCVF0cMWTwAGTDDx0jwA8FZMdF7AJRpQYLAidEQexJQaiDfeywAA+OyoEv2GcslDFQZsdF6Iwx6IIhltobsTHo"
			. "gDHDD1bAD4UxFOsvmSYglCZ5x0VC5IImaMdF4Mwo4GnCGPUa8SjgwCjDD7UjwA/FKINF5MAFMDtAReR9kA+2wJDwwAGEwA+E6IDvQVzlBpEwQZmN"
			. "idwt0GGgAFao4AcBbJgIbJgEbDXKICUKHDQK6f5DVIkKbOnqYALqEzjiE2Fvx5RF3Kwm3KIewRm/Ju2vJtygI+MHgeAHKIaFGkqQiBqQhBpgH94k"
			. "LLksDesbZgrkCWQJ9AYkHXMJOlAuv04tNItAGHCD+AF1YTCAEAoQkzIeIHEXA2Iw4wQGD5yFn+BDYwWBtjAYoAGh4Jdpx0XYbC/YYiduTgAEfy9t"
			. "L9hgL+MHDiPgB2Uv6YsCaQ+UF9VmD9RsD9RiB9cABH8PbW0P1GAP4weX4AdmDw9Vag8oZw/QbA/QYgdhW38PcA/QYA/jByFpD5OhYnIwjUgBQApN"
			. "YeYZwBAATIAGQQqJTCQCIME1lPj//+loY8QzwjUFdR9kBSw7mYUhOz1JBQIPhYOjbQCoSI2VcP///0XhBMFgmsdFzBIOSEETDi5Ii5V44AGLBEXM"
			. "gAoBwEyNBMOADT0OQQ+3EC8OIQ4OzJAACgRQXQ+3AGZRUHKe6apSPMgcFci5EhEUFh8VHxXtBsgQFdnzA9QVXTwqEaagDu8zOw9O2gXs0AWoSPF2"
			. "D4wQRPn///FcD4Td1eIMxOwMxOIIJ+AI7wyb7wwLB8QAB/MD5xRZc6/BlXJjkZPJBrzCAr3AArfPBs8Gywa8wAbzA33IBgiDRcBwAcA7RTDUfJCs"
			. "hV2khX2vha+FETiTSIHEAQxdw5BHAQAfpv2kgewwsSuNqKwkgEKljbOllYEjWEiLhWEAEBsUtQBI2MdACGIRAAmFogJxCT5QcAnTAIFQdQGhKIP4"
			. "iCB01S0BCnTCLQGIDXSvLQEJdJwtAXB7D4UpMlSvB6IHx0RFUDIQx0VYdABgcXIAiwUDUThxPrGiBYL18KNIx0QkQFMCCEQkOIIAjVUwSFCJVCQw"
			. "gABQgQAopZABICG4QbnxAUECFoK6ogKJwUH/0mAX+jjAa2jPEM8QzxDPEM8Qw88QJwF9D4TCYkdpAQqFYIesXgGD+CJ0hAq4IBD/6ZQRgQ4Hobpg"
			. "B8Ie6Pf9///QhcB0IgMCcwEC7wy/7wzvDO8M7wzvDCQBOhUKvPIQDwgICFIoxws6wwtNtAO2sgMgMouNAyxF+mg0SUJgDX8ajw2PDY8Nx48Njw0n"
			. "ASx1HW8HYwc86cLQC7CPjB3VDOgPF58QnBCwOQm2OYtVaNBIiVAIs9OrygOTBfBbD4Vlsnc/BfQzYsmdcAD4dABSQhAzw/v5M2a10QD/M41VQMXz"
			. "M/AX/zP/M+AZ2PAzcMeF/qy07h8aHxofGh8aHxofGrEnAV0PhNHinzTeR1DJKCfH+iknQw4xAuImrIuVcQxQDXBEJy3gKAEqDca1AI1QAkiLhcAA"
			. "IAAASIkQBZCLAAAPtwBmg/ggdCLVDZAKdMINSA10Iq8NJAl0nA0kLHWKJAckSArsg4WsAAiAAemq/v//kA03IF10Crj/AADpbC4NARUTQQAJyAAJ"
			. "ZscMAAkBIwELSItVcCBIiVAIuAALAOkGLwo8A1kiD4UTBWMaU4ULiYWgggQELJUHggaALQc7CADpWQSRDTGFwHWEXbAMDz9gXA+F9gMhP4RWdW40"
			. "AAmCPIETiQJCgDwiuZYg6ccKL4Q6FCNclxGqgJARL5QRL5cROZARSmKUEQiXEfICjxFmVZQRDJcRq5ARbpQRClWXEWSQEXKUEQ2XER2dkBF0lBFC"
			. "uJMR1gGPEXB1D4WFigWOmeQKALAAx4WcgWXhZTtDBsNBA8AIweAEicF+IgURT1MvfkJNAjl/LwfHB2IHxwMB0IPoMBnpCemuo2sqCEB+P1FNAkZ/"
			. "LJoKN4kK66pczQdgLwpmPApXKgophHnjCNcpg0IoAYNCvcEAAw+OuECaSKKDIggC6zrjB6PpB3AQSI1K5wchiiM+SDUgPo0DExJQLmCXkPuLQAtF"
			. "kkgmBynISIIWgeMCQAhIg+gEyzwbdRcjpQWqG6MNLXQuMW4+D44MiqfkPg+P4vXgoMeFmMEgh6YADzIUBqjHQGAMsAx1Is/jBqEk36KDBjB1ITjT"
			. "CkNNfnAOMA+OidACOTB/dutMhigAvYnQAEjB4AJIAdBIYAHASYnAaQwgNYsKlWMMCqAHSA+/wOhMAcBgD9AFCCPFTGYSH24Ofo4lTIEGAMIADuEu"
			. "D4Xm2BtIPgBmD+/A8kgPKmPBFGEC8g8R4EAGMQWFwDOUxDPrbIuVsQAEidDgDQHQAcCJ96IB/w32DZjAOwIG8AVwAAbScAASBGYPKMjyCA9eyjYH"
			. "EEAI8lgPWME8CFwQFw8kjiZq6h9jAWV0ngJFD9yF+I9N/RCzAhRXIv8Rsf8RxoWTDyoBKiGTASYBTwdDB+syPQMrdW4f3gQfLUsRE68hhCFohbI1"
			. "jFRa6zqLlbEA7cYbQZ8pnBtEER4xA18HQV8HfqDHhYiEIsfEhYRVBxyLlVEBKCOl4QCDAgIBi2IAOzIGkHzWgL2iD3QqWSF14BfJUCONUQMQIxoi"
			. "60oolwJIgxoPKvIF8rwPWb0k+R3BpdU6i1JEIEiYSA+vOTjrOPk6AwV1vwawBqEDvwa6BlIMtyIDAFNTzw98+FB0D4XfkhOAlRNSRouyAJAJjRUS"
			. "4JAPwLYEEGYPvkEKmAP0OcIlr3laBZ1moQTwFg0WBcDQAhEFhMB1lwAPtgUi5P//hPjAdB3JCqhS0j8VEWSFzBU+AwdXSwUsEgFDUAiLBR7RAInB"
			. "/9IFUw/Z/4b4Zg+F0wlRD0V8Ig9Mi0V83dIJJ9QJ/w73Don/PPcOaEV8AbUE23AClA6guZAOOOOfDkxhng40owZtmA4iEgGVDhTRAJcO76kvM/hu"
			. "lQ54lQ540gluQ9QJnw6XDp8PQZgOeJuQDrME92Enlw5+4pIOdiCJx8AMl9jJiS7FDlfb+wHgDUWEB8MON4IBxQ6E6wUyCkiBxDCQDPhdw5AJAKQs"
			. "DwAPAA8AAQAAIlVua25vdwBuX09iamVjdFBfAA0KMAoi1QB0AHJ1ZQBmYWxzQGUAbnVsbOcCVgBhbHVlXwAwMQAyMzQ1Njc4OQBBQkNERUYAVQBI"
			. "ieVIg8SASACJTRBIiVUYTECJRSDHRfwDV0UDwFURXyhIjU0YSACNVfxIiVQkKJDHRCQg8QFBuTEwEEmJyLrTAk0Q/yDQSMdF4NIAx0UK6HQA8LQE"
			. "IEiJRQ7g4ABTjaIFTItQMFCLRfxIEAVA0wJEFCQ4hQAwggCNVeA/RgfAW0AHogeCFnGaTRCYQf/S0QWE83UeogafgZviGWAG5ADxGetgpwIYA3VT"
			. "tQEBDIBIOazQfUBy1AK6EBx/YhwoOdB/4FdF8Q/YSQtwjFMH6KErhcB0D7UAD0iLRdhIi1UAIEiLUghIiRAAkEiD7IBdw5AhBQBVSInlAEhgSACJ"
			. "TRCJVRhMiQBFIGbHRegAAACLRRiJRfjHRQj8FAAAGE0YicoAuM3MzMxID68AwkjB6CCJwsEA6gOJ0MHgAgEA0AHAKcGJyokA0IPAMINt/AEAicKL"
			. "RfxImGZQiVRFwAGKwgo4wQDoA4lFGIN9GMAAdalIjVUAIQArQEgBwEgB0AGmSQCJ0EiJwkiLTUAQ6AH+//8ArsTWYAiuBa9wAa9IBLAApIEAowDp"
			. "rgIAAADuIBBIi1AYA1bB4KIFgSuJRdCBB2OAMAGBDkAwSDnCD43QmgEAAIB1uAIaAA0CQAAoRfDGRe8AgEiDffAAeQgABeABSPdd8ICHAYIASiDw"
			. "SLpnZgMASIkgyEj36kgAV8H4AAJJichJwfg/mEwpwAFegQngAgE8UQBrKcFIho3ogo3ohYONkJgnSMH5PwAbFEgpgV3wAkd1gIBgfe8AdBCBIoMh"
			. "x6BERZAtAIChkIIHAYShiUXAxkXnAIjHReCBiYtF4EAGjI0UgTiBBw+3EIQEAgyBBBhIAcgPt0AAZjnCdW+PCgDgZoXAdR7JBcALxQUiBkAZAes6"
			. "Uw10IgFTDXQKg0XgAekEZv9AdoB95wAPVIT2AlZFgKdVwC4QYrjAZADpAUABCmw4GQFsjMrDCoVqyMZFqt/AOdjDOdiGG8jFOb+CBNA5jQrFOccF"
			. "yznfwjkvUQ3BOVENwTnYxjnfAAR0Es046yCDRfwLAHIIOSACOTv9//+DgKRAOoPEcF3DwrvYgeyQAQSEvEjEdsABm8DpwgHwwQHAsuAFAsCA8g8Q"
			. "APIPEUCFqMdFwEQEyOQA0OIAHo3AMyBFwAGBEUiLBQBE5v//SIsATCiLUDCgATahAcdERCRAgwZEJDgCAYthgA+JVCQw4XYBASilIAMgAQhBueED"
			. "QeIWArpCBYnBQf/SSOyBxAEX8HdA6XcDjkSNx4MhAAjkXg+Jm39veW/kuDDgBynQLZO/b6lveA+FemA5YQgjCGBvwPAtAOmAXxPfgh8T2oJIx0Xs"
			. "IS7rUOABGFgAdDaLqgAL7EIBTJiNBAJiVGArjUhAAQlhOQpBAGVmiRDrgcHEIIsAjVABAQHAiRCDRewBFAlHY9qO5VRAJzzkOyDpOwMTAhyvD2bH"
			. "ACIA6UxeBEOAyA/pSmMCEEEhDYP4InVmYwgZmXIIXADuF1wO5gNPDnbSYwJEDlxfDl8OyAXp6nNQDl9KDghfDl8OxgXQYgDpAFAO7DRyIwc+DC8H"
			. "LwcvBy8H4gJmAKzpjeMFKgd5KgcKLwcPLwcvBy8H4gJuAOka6S8H6QYqBw0vBy8HLwfDLwfiAnIA6acwTy0H9pMzASQHCS8HLwcvBy8HoeICdADp"
			. "NC8H6aFXAA+2BTnW//+EiMB0K9cHH3YNxwAofnYHE2cF4jqD4KgB6zapAhqpAhTFALA9oAB3fQNABnxfDW9fDV4N7wLhAnXvAtQHDxa3UVDxchgg"
			. "VInB6OqGcQg0wwQezwRgAGADZhKPTAEIRRBxT0INheDAD4Wm+6BtXwnYQXs+BEGoICRO9U1gWdVrieEAa40FQvNwBVBZxKgA6zIPt0UQg+AOD9Ks"
			. "wFpQU7YAZg8WvpKokl7oEQJmwegGBBEE0YCDffwDfhDIx0X4cDsA6z8BUwoli0X4SJhEGA+3ROB8DgtEicITXw/gW2340AT4AHkGuyVa9Qs="
			static Code := false
			if ((A_PtrSize * 8) != 64) {
				Throw Exception("_LoadLib64Bit does not support " (A_PtrSize * 8) " bit AHK, please run using 64 bit AHK")
			}
			; MCL standalone loader https://github.com/G33kDude/MCLib.ahk
			; Copyright (c) 2021 G33kDude, CloakerSmoker (CC-BY-4.0)
			; https://creativecommons.org/licenses/by/4.0/
			if (!Code) {
				CompressedSize := VarSetCapacity(DecompressionBuffer, 4280, 0)
				if !DllCall("Crypt32\CryptStringToBinary", "Str", CodeBase64, "UInt", 0, "UInt", 1, "Ptr", &DecompressionBuffer, "UInt*", CompressedSize, "Ptr", 0, "Ptr", 0, "UInt")
					throw Exception("Failed to convert MCLib b64 to binary")
				if !(pCode := DllCall("GlobalAlloc", "UInt", 0, "Ptr", 11280, "Ptr"))
					throw Exception("Failed to reserve MCLib memory")
				DecompressedSize := 0
				if (DllCall("ntdll\RtlDecompressBuffer", "UShort", 0x102, "Ptr", pCode, "UInt", 11280, "Ptr", &DecompressionBuffer, "UInt", CompressedSize, "UInt*", DecompressedSize, "UInt"))
					throw Exception("Error calling RtlDecompressBuffer",, Format("0x{:08x}", r))
				OldProtect := 0
				if !DllCall("VirtualProtect", "Ptr", pCode, "Ptr", 11280, "UInt", 0x40, "UInt*", OldProtect, "UInt")
					Throw Exception("Failed to mark MCLib memory as executable")
				Exports := {}
				for ExportName, ExportOffset in {"bBoolsAsInts": 0, "bEmptyObjectsAsArrays": 16, "bEscapeUnicode": 32, "bNullsAsStrings": 48, "dumps": 64, "fnCastString": 2672, "fnGetObj": 2688, "loads": 2704, "objFalse": 7728, "objNull": 7744, "objTrue": 7760} {
					Exports[ExportName] := pCode + ExportOffset
				}
				Code := Exports
			}
			return Code
		}
		_LoadLib() {
			return A_PtrSize = 4 ? this._LoadLib32Bit() : this._LoadLib64Bit()
		}
		
		Dump(obj, pretty := 0)
		{
			this._init()
			if (!IsObject(obj))
				throw Exception("Input must be object")
			size := 0
			DllCall(this.lib.dumps, "Ptr", &obj, "Ptr", 0, "Int*", size
			, "Int", !!pretty, "Int", 0, "CDecl Ptr")
			VarSetCapacity(buf, size*2+2, 0)
			DllCall(this.lib.dumps, "Ptr", &obj, "Ptr*", &buf, "Int*", size
			, "Int", !!pretty, "Int", 0, "CDecl Ptr")
			return StrGet(&buf, size, "UTF-16")
		}
		
		Load(ByRef json)
		{
			this._init()
			
			_json := " " json ; Prefix with a space to provide room for BSTR prefixes
			VarSetCapacity(pJson, A_PtrSize)
			NumPut(&_json, &pJson, 0, "Ptr")
			
			VarSetCapacity(pResult, 24)
			
			if (r := DllCall(this.lib.loads, "Ptr", &pJson, "Ptr", &pResult , "CDecl Int")) || ErrorLevel
			{
				throw Exception("Failed to parse JSON (" r "," ErrorLevel ")", -1
				, Format("Unexpected character at position {}: '{}'"
				, (NumGet(pJson)-&_json)//2, Chr(NumGet(NumGet(pJson), "short"))))
			}
			
			result := ComObject(0x400C, &pResult)[]
			if (IsObject(result))
				ObjRelease(&result)
			return result
		}
		
		True[]
		{
			get
			{
				static _ := {"value": true, "name": "true"}
				return _
			}
		}
		
		False[]
		{
			get
			{
				static _ := {"value": false, "name": "false"}
				return _
			}
		}
		
		Null[]
		{
			get
			{
				static _ := {"value": "", "name": "null"}
				return _
			}
		}
	}
	
}
