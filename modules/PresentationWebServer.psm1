$script:PresentationWebServerName = "PresentationWebServer"

function Start-PresentationWebServer {
    param (
        [string] $Prefix = "http://localhost:18383/"
    )

    # Clear out old jobs. The presentation can leave some running if it exits early and they're using static listening ports so they need to be killed
    Get-Job -Name "*$script:PresentationWebServerName*" | Stop-Job
    Get-Job -Name "*$script:PresentationWebServerName*" | Remove-Job

    $null = Start-Job -Name $script:PresentationWebServerName -ScriptBlock {

        $http = [System.Net.HttpListener]::new()
        $http.Prefixes.Add($using:Prefix)
        $http.Start()
        try {
            while ($http.IsListening) {
                $contextTask = $http.GetContextAsync()
                while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) { }
                $context = $contextTask.GetAwaiter().GetResult()
                
                $requestStream = [System.IO.StreamReader]::new($context.Request.InputStream)
                $requestText = $requestStream.ReadToEnd()

                $response = "Not Found"
                $context.Response.StatusCode = "404"

                if($context.Request.RawUrl -eq '/build') {
                    if($requestText -like "*System.Object*") {
                        $response = "Bad Request"
                        $context.Response.StatusCode = "400"
                    } else {
                        $response = "Build Triggered"
                        $context.Response.StatusCode = "201"
                    }
                }

                if($context.Request.RawUrl -eq '/projects') {
                    $response = @'
[
    {
        "Name": "Demo Project 1",
        "Id": 9000,
        "SettingsV2": {
            "Default": "x86",
            "Architectures": [ "x86", "x64" ]
        }
    }
]
'@
                    $context.Response.StatusCode = "200"
                }

                $buffer = [System.Text.Encoding]::UTF8.GetBytes($response)
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                $context.Response.OutputStream.Close()
            }
        }
        finally {
            $http.Stop()
        }
    }
}

function Stop-PresentationWebServer {
    # Clear out old jobs. The presentation can leave some running if it exits early and they're using static listening ports so they need to be killed
    Get-Job -Name "*$script:PresentationWebServerName*" | Receive-Job | Out-Null
    Get-Job -Name "*$script:PresentationWebServerName*" | Stop-Job
    Get-Job -Name "*$script:PresentationWebServerName*" | Remove-Job
}