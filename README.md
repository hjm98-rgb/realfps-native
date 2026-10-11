# 真实战场 · 原生 iOS 3D 开放世界 FPS（非套壳）

用 **Swift + SceneKit（苹果官方原生 3D 引擎）** 写的真原生第一人称射击游戏，
**GitHub 云端打包 + 你的证书签名 → 原生 .ipa**，直接装进你的 iPad。不用 Unity、不用网页套壳。

## 功能（按你的要求）
- **大开放世界**：地图 6000×6000 超大，无边界感，只有**空气墙在极远处（地图边缘）**才拦人
- **第一/第三人称切换按钮**：可自由切换视角
- **真实 3D 人物**：玩家和敌人都是精致的 3D 人体（头部/躯干/双臂/双腿/装备），不是多边形块
- **多种敌人**：普通兵、快速突击者、重型猛汉（体型/速度/血量/伤害不同）
- **背景故事**：开场剧情介绍，废土战场世界观
- **数据保存**：击杀、波次、金币自动存档（UserDefaults），下次打开还在
- **云打包签名**：用你的 Ad-Hoc 证书签名，出能直接安装的 .ipa
- 触控按键：左摇杆移动、右侧拖动视角、开火键、换弹键

## 目录
| 文件 | 作用 |
|---|---|
| `3DGame/GameScene.swift` | 开放世界/人物/敌人/第一三人称/数据保存/射击 |
| `3DGame/GameViewController.swift` | 主菜单/故事/HUD/视角切换/触控按键 |
| `3DGame/AppDelegate.swift` | 入口 |
| `project.yml` | XcodeGen 工程配置（包名 com.cert.account.t260901214911，Team 2TAD594A66） |
| `.github/workflows/build-ipa.yml` | 云打包+证书签名 → 原生 .ipa |

## 一键云打包
1. 把整个文件夹推到 GitHub 仓库（公开仓库有免费 macOS 编译分钟）。
2. 仓库 Settings → Secrets 添加：
   - `IOS_P12_BASE64`：证书 `2603802E.p12` 的 base64
   - `IOS_P12_PASSWORD`：`1`
   - `IOS_MOBILEPROVISION_BASE64`：`2603802E.mobileprovision` 的 base64
3. Actions → **云打包IPA** → Run workflow。
4. 在 Artifacts 下载 **RealFPS.ipa**，直接装到绑定的 iPad（UDID 已在你描述文件里）。

## 关于"更真实的 3D 人物模型"
要做到真人级建模，需要去 **Mixamo（免费带动作）**、**Sketchfab** 等网站下载 FBX/USDZ 人物模型，
放进工程即可替换当前的组合人体。这一步需要模型文件（任何 AI 都画不出真人级 3D 模型）。
