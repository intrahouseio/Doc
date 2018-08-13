$Host.UI.RawUI.BackgroundColor = ($bckgrnd = 'Black')
Clear-Host

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$testadmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if ($testadmin -eq $false) {
Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -InputFormat None -ExecutionPolicy Bypass -NoExit  -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
exit $LASTEXITCODE
}

#-------------- options
$repo_name="intraHouse-Cherry"
$name_service="intrahouse-c"
$project_name="project_$([int](Get-Date -UFormat %s -Millisecond 0))"
$port=8088

$root="$($env:LOCALAPPDATA)\$($name_service)"
$project_path="C:\ProgramData\$($name_service)\projects\$($project_name)"

$lang="en"

#-------------- end


#-------------- check

if (Get-Service -Name "$name_service" -ErrorAction SilentlyContinue) {
cmd /c "SC STOP intrahousec.exe" | Out-Null
}
#-------------- end


#-------------- tools

function unzip($args) {
    Start-Process "$root\7z.exe" -ArgumentList $args
}
#-------------- end


#-------------- logo

Write-Host -ForegroundColor Blue "

   ______          __                   __  __
  /\__  _\        /\ \__               /\ \/\ \
  \/_/\ \/     ___\ \  _\  _ __    __  \ \ \_\ \    ___   __  __    ____     __
     \ \ \   /  _  \ \ \/ /\  __\/ __ \ \ \  _  \  / __ \/\ \/\ \  /  __\  / __ \
      \_\ \__/\ \/\ \ \ \_\ \ \//\ \ \.\_\ \ \ \ \/\ \L\ \ \ \_\ \/\__,  \/\  __/
      /\_____\ \_\ \_\ \__\\ \_\\ \__/.\_\\ \_\ \_\ \____/\ \____/\/\____/\ \____\
      \/_____/\/_/\/_/\/__/ \/_/ \/__/\/_/ \/_/\/_/\/___/  \/___/  \/___/  \/____/


                             Software for Automation Systems

-----------------------------------------------------------------------------------

"

#-------------- end

Write-Host -ForegroundColor DarkCyan "...installing"

#-------------- creation of structures

Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $root
New-Item -ItemType Directory -Force -Path $root | Out-Null
New-Item -ItemType Directory -Force -Path "$root\tools" | Out-Null

#-------------- end


#-------------- generate config

$config = "{
  `"port`":$port,
  `"project`":`"$project_name`",
  `"name_service`":`"$name_service`",
  `"vardir`":`"C:`/ProgramData`/`",
  `"lang`":`"$lang`"
}
"
[IO.File]::WriteAllLines("$($root)/config.json", $config)

#-------------- end


#-------------- check dependencies
Write-Host -ForegroundColor DarkYellow "`r`nCheck dependencies:`r`n"
Write-Host "get 7-Zip"
Invoke-WebRequest -Uri "https://github.com/develar/7zip-bin/raw/master/win/ia32/7za.exe" -OutFile "$root\tools\7z.exe"
#Write-Host -ForegroundColor DarkMagenta " 7-Zip: " -NoNewline; Write-Host -ForegroundColor DarkGreen "true`r`n"

#-------------- end


#-------------- download files
Write-Host -ForegroundColor DarkYellow "`r`nDownload:`r`n"
Write-Host "search $($name_service)"

$file = (Invoke-RestMethod -Uri "https://api.github.com/repos/intrahouseio/$repo_name/releases/latest").assets[0].browser_download_url
Write-Host "latest found: " -NoNewline; Write-Host -ForegroundColor DarkGreen "$($file)`r`n"

Write-Host "get $($name_service)"
Invoke-WebRequest -Uri $file -OutFile "$root\intrahouse-lite.zip"

Write-Host "get nodeJS"
Invoke-WebRequest -Uri "http://nodejs.org/dist/v8.7.0/node-v8.7.0-win-x86.zip" -OutFile "$root\node.zip"


#-------------- end


#-------------- deploy
Write-Host -ForegroundColor DarkYellow "`r`nDeploy:`r`n"
cmd /c "$root\tools\7z.exe" x -y "$root\intrahouse-lite.zip" -o"$root\"
cmd /c "$root\tools\7z.exe" x -y "$root\node.zip" -o"$root\"

Set-Location "$root\backend"
cmd /c "$root\node-v8.7.0-win-x86\node.exe" "$root\node-v8.7.0-win-x86\node_modules\npm\bin\npm-cli.js" i --only=prod
Set-Location "$root"
cmd /c "$root\node-v8.7.0-win-x86\node.exe" "$root\node-v8.7.0-win-x86\node_modules\npm\bin\npm-cli.js" i node-windows --only=prod

Copy-Item "$root\project_$lang" -Force -Recurse -ErrorAction SilentlyContinue -Destination "$project_path"

Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$root\node.zip"
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$root\intrahouse-lite.zip"
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$root\project_*"


#-------------- end


#-------------- register service
Write-Host -ForegroundColor DarkCyan "`r`n...register service`r`n"

$service="var Service = require('node-windows').Service;

var svc = new Service({
  name:'intrahouse-c',
  description: 'Software platform for automation systems',
  script: '$root\backend\app.js',
  nodeOptions: [],
  env: [{
    name: `"prod`",
    value: true,
  }]
});

svc.on('install', () => svc.start());
svc.install('$root');
"

[IO.File]::WriteAllLines("$($root)/service.js", $service.replace("\","\\"))

if (Get-Service -Name "$name_service" -ErrorAction SilentlyContinue) {
cmd /c "$root\node-v8.7.0-win-x86\node.exe" "$root\service.js"
} else {
cmd /c "$root\node-v8.7.0-win-x86\node.exe" "$root\service.js"
}

cmd /c sc query intrahousec.exe
#-------------- end


#-------------- get ip address server
$myip=((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
#-------------- end



#-------------- display info complete

Write-Host -ForegroundColor Blue "`r`n-----------------------------------------------------------------------------------`r`n"
Write-Host -ForegroundColor DarkCyan "Web interface: " -NoNewline; Write-Host -ForegroundColor DarkMagenta "http://$($myip):$($port)/pm/"
Write-Host -ForegroundColor DarkCyan "Complete! Thank you."
Write-Host -ForegroundColor DarkCyan ""

#-------------- end