# 自检.ps1 —— 跑这个项目自带的三套检查。
#
# 用法（在项目根目录）：
#   pwsh -File 自检.ps1
#
# ⚠️ 为什么要用脚本，不能直接敲命令：
#   Steam 版的 Godot（godot.windows.opt.tools.64.exe）是 Windows GUI 子系统程序，
#   没有挂控制台，PowerShell 直接管道抓不到它的输出。
#   所以这里用 cmd 把输出重定向到临时文件，再读回来。
#
# ⚠️ 版本必须和编辑器一致。
#   本项目用 Godot 4.7，编辑器也是 4.7。
#   用别的版本跑 --import 会重写 .godot/ 缓存，把编辑器搞乱。

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------- 配置 ----------------
$godot = "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if (-not (Test-Path $godot)) {
    Write-Host ""
    Write-Host "找不到 Godot：$godot" -ForegroundColor Red
    Write-Host "把 自检.ps1 顶部那一行改成你编辑器用的那个 Godot 的路径。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "★ 一定用**和编辑器同一个版本**。用别的版本跑，会重写 .godot/ 缓存，把编辑器搞乱。" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
$proj = $PSScriptRoot
$tmp  = Join-Path $env:TEMP "storycat_selfcheck.txt"

# ---------------- 要跑的三套 ----------------
$套件 = @(
    @{ 名 = "引擎机制"; 路径 = "res://脚本/测试/机制自检.gd"; 项数 = 59 },
    @{ 名 = "剧本数据"; 路径 = "res://脚本/测试/剧本自检.gd"; 项数 = 22 },
    @{ 名 = "界面整局"; 路径 = "res://脚本/测试/对局自检.gd"; 项数 = 76 }
)

Write-Host ""
Write-Host "Godot：$godot" -ForegroundColor DarkGray
Write-Host "项目：$proj" -ForegroundColor DarkGray

$总失败 = 0

foreach ($s in $套件) {
    Write-Host ""
    Write-Host "───── $($s.名) ─────" -ForegroundColor Cyan

    cmd /c "`"$godot`" --headless --path `"$proj`" --script `"$($s.路径)`" > `"$tmp`" 2>&1"
    $行 = Get-Content $tmp -Encoding UTF8 -ErrorAction SilentlyContinue

    if (-not $行) {
        Write-Host "  ★ 没有输出 —— 脚本没跑起来。" -ForegroundColor Red
        $总失败++
        continue
    }

    # 失败的条目
    $挂 = $行 | Select-String -Pattern "\[XX\]"
    if ($挂) {
        foreach ($l in $挂) { Write-Host "  $($l.Line.Trim())" -ForegroundColor Red }
    }

    # 脚本运行错误
    $错 = $行 | Select-String -Pattern "SCRIPT ERROR|Parse Error|Compile Error"
    if ($错) {
        Write-Host "  脚本报错 $($错.Count) 条：" -ForegroundColor Red
        foreach ($l in ($错 | Select-Object -First 5)) { Write-Host "    $($l.Line.Trim())" }
    }

    # 结果
    $结 = $行 | Select-String -Pattern "通过 (\d+) · 失败 (\d+)"
    if ($结) {
        $m = [regex]::Match($结.Line, "通过 (\d+) · 失败 (\d+)")
        $过 = [int]$m.Groups[1].Value
        $败 = [int]$m.Groups[2].Value
        $总失败 += $败
        $色 = if ($败 -eq 0) { "Green" } else { "Red" }
        Write-Host "  通过 $过 · 失败 $败" -ForegroundColor $色
    } else {
        Write-Host "  ★ 没跑到结尾就退出了。" -ForegroundColor Red
        $总失败++
    }
}

# ---------------- 主场景能不能起来 ----------------
Write-Host ""
Write-Host "───── 主场景冒烟 ─────" -ForegroundColor Cyan
cmd /c "`"$godot`" --headless --path `"$proj`" --quit-after 240 > `"$tmp`" 2>&1"
$行 = Get-Content $tmp -Encoding UTF8 -ErrorAction SilentlyContinue
$错 = $行 | Select-String -Pattern "SCRIPT ERROR|Parse Error|ERROR:"
if ($错) {
    Write-Host "  ★ 有报错 $($错.Count) 条：" -ForegroundColor Red
    foreach ($l in ($错 | Select-Object -First 8)) { Write-Host "    $($l.Line.Trim())" }
    $总失败++
} else {
    Write-Host "  干净" -ForegroundColor Green
}

# ---------------- 总结 ----------------
Write-Host ""
if ($总失败 -eq 0) {
    Write-Host "════ 全过 ════" -ForegroundColor Green
} else {
    Write-Host "════ 有 $总失败 处问题 ════" -ForegroundColor Red
    Write-Host ""
    Write-Host "挂了通常只有两种可能：" -ForegroundColor Yellow
    Write-Host "  ① 你碰了 脚本/系统/对局.gd  或  脚本/系统/口径.gd"
    Write-Host "  ② 你改了 脚本/数据/口径词表.gd 的**格式**（字段名、结构）"
    Write-Host ""
    Write-Host "如果报的是 `"Cannot load ... / Failed loading resource`" —— 那是 UID 缓存过期，"
    Write-Host "不是代码问题：把 .godot/uid_cache.bin 删掉，重开编辑器就好。"
}
Write-Host ""
