import SceneKit
import QuartzCore

func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 { SCNVector3(l.x + r.x, l.y + r.y, l.z + r.z) }
func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 { SCNVector3(l.x - r.x, l.y - r.y, l.z - r.z) }
func * (v: SCNVector3, s: Float) -> SCNVector3 { SCNVector3(v.x * s, v.y * s, v.z * s) }

// 精致 3D 人体（头部/躯干/双臂/双腿，带装备）——玩家与敌人共用
func makeHumanoid(scale: CGFloat, main: UIColor, gear: UIColor) -> SCNNode {
    let root = SCNNode()
    func part(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, color: UIColor, x: CGFloat, y: CGFloat, z: CGFloat) {
        let g = SCNBox(width: w, height: h, length: d, chamferRadius: min(w, h, d) * 0.2)
        g.firstMaterial?.diffuse.contents = color
        g.firstMaterial?.roughness.contents = 0.9
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(x, y, z)
        root.addChildNode(n)
    }
    let s = scale
    part(0.16 * s, 0.7 * s, 0.16 * s, color: gear, x: -0.09 * s, y: 0.35 * s, z: 0)
    part(0.16 * s, 0.7 * s, 0.16 * s, color: gear, x: 0.09 * s, y: 0.35 * s, z: 0)
    part(0.46 * s, 0.6 * s, 0.26 * s, color: main, x: 0, y: 1.0 * s, z: 0)
    part(0.4 * s, 0.5 * s, 0.16 * s, color: UIColor(white: 0.2, alpha: 1), x: 0, y: 1.05 * s, z: -0.2 * s)
    part(0.12 * s, 0.55 * s, 0.12 * s, color: main, x: -0.34 * s, y: 1.0 * s, z: 0)
    part(0.12 * s, 0.55 * s, 0.12 * s, color: main, x: 0.34 * s, y: 1.0 * s, z: 0)
    part(0.3 * s, 0.28 * s, 0.3 * s, color: UIColor(red: 0.75, green: 0.6, blue: 0.5, alpha: 1), x: 0, y: 1.45 * s, z: 0)
    part(0.34 * s, 0.12 * s, 0.34 * s, color: gear, x: 0, y: 1.6 * s, z: 0)
    return root
}

// 大开放世界 原生 SceneKit FPS（第一/第三人称、空气墙边界、数据保存、故事）
final class Game: NSObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let playerNode = SCNNode()   // 玩家身体（第三人称用）
    private let gunNode = SCNNode()
    enum CamMode { case first, third }
    private(set) var camMode: CamMode = .first

    // 输入
    var lookDX: Float = 0
    var lookDY: Float = 0
    var moveX: Float = 0
    var moveZ: Float = 0
    private var fireHeld = false

    // 状态
    private(set) var running = false
    private(set) var health = 100
    private(set) var ammo = 30
    private(set) var kills = 0
    private(set) var wave = 1
    private(set) var coins = 0
    private(set) var gameOver = false
    private var reloading = false
    private var reloadTime: TimeInterval = 0
    private var nextFire: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var yaw: Float = 0
    private var pitch: Float = 0
    private var enemies: [Enemy] = []

    let magSize = 30
    let maxWaves = 10
    // 空气墙边界（非常远，到达地图边缘才有）
    private let boundary: Float = 3000

    var onHUD: (() -> Void)?
    var onGameOver: ((Bool) -> Void)?

    // MARK: - 场景
    func setupScene() {
        scene.background.contents = UIColor(red: 0.55, green: 0.62, blue: 0.75, alpha: 1)
        scene.fogStartDistance = 150
        scene.fogEndDistance = 2600
        scene.fogColor = UIColor(red: 0.5, green: 0.56, blue: 0.68, alpha: 1)

        // 光照
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 320
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional
        sun.light?.castsShadow = true; sun.light?.shadowMapSize = CGSize(width: 4096, height: 4096); sun.light?.shadowFar = 600
        sun.position = SCNVector3(80, 160, -60); sun.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(sun)

        // 大地面（开放世界）
        let ground = SCNBox(width: CGFloat(boundary * 2), height: 1, length: CGFloat(boundary * 2), chamferRadius: 0)
        ground.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.36, blue: 0.24, alpha: 1)
        ground.firstMaterial?.roughness.contents = 1
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(0, -0.5, 0)
        groundNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        scene.rootNode.addChildNode(groundNode)

        // 空气墙：四个方向，放在地图边界外很远（不可见，阻挡越界）
        let wallGeo = SCNBox(width: CGFloat(boundary * 2), height: 200, length: 4, chamferRadius: 0)
        wallGeo.firstMaterial?.diffuse.contents = UIColor.clear
        wallGeo.firstMaterial?.writeToScreen = false
        wallGeo.firstMaterial?.isDoubleSided = false
        for (dir, x, z) in [(1.0, boundary + 2, 0.0), (1.0, -(boundary + 2), 0.0), (1.0, 0.0, boundary + 2), (1.0, 0.0, -(boundary + 2))] {
            _ = dir
            let w = SCNNode(geometry: wallGeo)
            w.position = SCNVector3(Float(x), 100, Float(z))
            w.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            scene.rootNode.addChildNode(w)
        }

        addOpenWorld()

        // 玩家
        playerNode.position = SCNVector3(0, 0, 0)
        playerNode.name = "player"
        buildPlayerBody()
        scene.rootNode.addChildNode(playerNode)

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 4000
        cameraNode.camera?.fieldOfView = 70
        scene.rootNode.addChildNode(cameraNode)

        buildGun()
    }

    private func addOpenWorld() {
        // 散落掩体/建筑
        let crateColors: [UIColor] = [.darkGray, .systemBrown, UIColor(red: 0.42, green: 0.4, blue: 0.32, alpha: 1)]
        for _ in 0..<220 {
            let a = Float.random(in: 0...(2 * .pi))
            let r = Float.random(in: 30...2000)
            let s = SCNBox(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 1.2...4), length: CGFloat.random(in: 2...6), chamferRadius: 0.1)
            s.firstMaterial?.diffuse.contents = crateColors.randomElement()
            s.firstMaterial?.roughness.contents = 1
            let n = SCNNode(geometry: s)
            n.position = SCNVector3(cos(a) * r, 0, sin(a) * r)
            n.position.y = Float(n.geometry!.boundingBox.max.y / 2)
            n.castsShadow = true
            n.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            scene.rootNode.addChildNode(n)
        }
        // 远处群山（增加开放世界纵深感）
        for _ in 0..<60 {
            let a = Float.random(in: 0...(2 * .pi))
            let r = Float.random(in: 1800...2900)
            let h = Float.random(in: 80...260)
            let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat.random(in: 80...160), height: CGFloat(h))
            cone.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.34, blue: 0.44, alpha: 1)
            let n = SCNNode(geometry: cone)
            n.position = SCNVector3(cos(a) * r, h / 2, sin(a) * r)
            scene.rootNode.addChildNode(n)
        }
    }

    // 精致的 3D 人体（头部/躯干/双臂/双腿）
    private func buildPlayerBody() {
        let body = makeHumanoid(scale: 1.0, main: UIColor(red: 0.18, green: 0.30, blue: 0.35, alpha: 1), gear: UIColor(red: 0.15, green: 0.2, blue: 0.25, alpha: 1))
        body.name = "playerBody"
        playerNode.addChildNode(body)
    }

    private func buildGun() {
        let body = SCNBox(width: 0.09, height: 0.12, length: 0.65, chamferRadius: 0.02)
        body.firstMaterial?.diffuse.contents = UIColor(white: 0.12, alpha: 1); body.firstMaterial?.metalness.contents = 0.9
        let bN = SCNNode(geometry: body); bN.position = SCNVector3(0, 0, -0.35)
        let barrel = SCNCylinder(radius: 0.025, height: 0.5)
        barrel.firstMaterial?.diffuse.contents = UIColor(white: 0.08, alpha: 1); barrel.firstMaterial?.metalness.contents = 1
        let rN = SCNNode(geometry: barrel); rN.position = SCNVector3(0, 0.02, -0.95); rN.eulerAngles.x = -Float.pi / 2
        let grip = SCNBox(width: 0.06, height: 0.22, length: 0.09, chamferRadius: 0.02)
        grip.firstMaterial?.diffuse.contents = UIColor(white: 0.16, alpha: 1)
        let gN = SCNNode(geometry: grip); gN.position = SCNVector3(0, -0.16, -0.1); gN.eulerAngles.x = 0.3
        let mag = SCNBox(width: 0.05, height: 0.2, length: 0.1, chamferRadius: 0.02)
        mag.firstMaterial?.diffuse.contents = UIColor(white: 0.14, alpha: 1)
        let mN = SCNNode(geometry: mag); mN.position = SCNVector3(0, -0.14, -0.35)
        gunNode.addChildNode(bN); gunNode.addChildNode(rN); gunNode.addChildNode(gN); gunNode.addChildNode(mN)
        gunNode.position = SCNVector3(0.28, -0.28, -0.5)
        cameraNode.addChildNode(gunNode)
    }

    // MARK: - 数据保存（UserDefaults）
    private let saveKey = "realfps.progress"
    struct Progress: Codable { var bestWave: Int = 0; var totalKills: Int = 0; var coins: Int = 0 }
    func loadProgress() -> Progress {
        guard let d = UserDefaults.standard.data(forKey: saveKey),
              let p = try? JSONDecoder().decode(Progress.self, from: d) else { return Progress() }
        return p
    }
    private func saveProgress() {
        var p = loadProgress()
        p.bestWave = max(p.bestWave, wave)
        p.totalKills += kills
        p.coins += coins
        if let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: saveKey) }
    }

    // MARK: - 控制
    func toggleCameraMode() { camMode = (camMode == .first) ? .third : .first; onHUD?() }
    func start() {
        running = true; gameOver = false
        health = 100; ammo = magSize; kills = 0; wave = 1; coins = 0
        playerNode.position = SCNVector3(0, 0, 0); yaw = 0; pitch = 0
        enemies.forEach { $0.node.removeFromParentNode() }; enemies.removeAll()
        spawnWave()
        onHUD?()
    }
    func setFire(_ on: Bool) { fireHeld = on }
    func setMove(_ x: Float, _ z: Float) { moveX = x; moveZ = z }
    func addLook(_ dx: Float, _ dy: Float) { lookDX += dx; lookDY += dy }
    func reload() { if reloading || ammo == magSize || !running { return }; reloading = true; reloadTime = 1.6 }

    private func spawnWave() {
        let count = 3 + wave
        for _ in 0..<count {
            let a = Float.random(in: 0...(2 * .pi))
            let r = Float.random(in: 20...220)
            spawnEnemy(at: SCNVector3(cos(a) * r, 0, sin(a) * r))
        }
    }

    private func spawnEnemy(at pos: SCNVector3) {
        let type: EnemyType
        if wave >= 3 && Float.random(in: 0...1) < 0.25 { type = .brute }
        else if wave >= 2 && Float.random(in: 0...1) < 0.3 { type = .runner }
        else { type = .grunt }
        let node = Enemy.makeNode(type: type)
        node.position = SCNVector3(pos.x, 0, pos.z)
        node.name = "enemy"
        scene.rootNode.addChildNode(node)
        enemies.append(Enemy(node: node, type: type))
    }

    // MARK: - 开火
    private func fire() {
        guard ammo > 0, !reloading, running else { return }
        ammo -= 1; nextFire = CACurrentMediaTime() + 0.13
        if camMode == .first {
            gunNode.runAction(.sequence([.move(to: SCNVector3(0.28, -0.24, -0.25), duration: 0.05),
                                         .move(to: SCNVector3(0.28, -0.28, -0.5), duration: 0.12)]))
        }
        // 射线
        let origin = cameraNode.presentation.position
        var dir = SCNVector3(0, 0, -1)
        dir = normalize(cameraNode.convertVector(dir, to: scene.rootNode))
        let hit = scene.rootNode.hitTestWithSegment(from: origin, to: origin + dir * 300, options: nil).first
        if let h = hit, let n = h.node, n.name == "enemy",
           let idx = enemies.firstIndex(where: { $0.node === n }) {
            killEnemy(at: idx)
        }
        onHUD?()
    }

    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let l = sqrt(v.x * v.x + v.y * v.y + v.z * v.z); guard l > 0 else { return v }
        return SCNVector3(v.x / l, v.y / l, v.z / l)
    }

    private func killEnemy(at idx: Int) {
        let e = enemies.remove(at: idx)
        e.node.runAction(.sequence([.scale(to: 0.05, duration: 0.15), .removeFromParentNode()]))
        kills += 1; coins += e.type == .brute ? 5 : (e.type == .runner ? 2 : 1)
        onHUD?()
        if enemies.isEmpty { waveCheck() }
    }

    // MARK: - 更新
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard running else { return }
        if lastTime == 0 { lastTime = time }
        let dt = Float(min(time - lastTime, 0.05)); lastTime = time

        yaw += lookDX * dt
        if camMode == .first { pitch = min(1.3, max(-1.3, pitch + lookDY * dt)) }
        lookDX = 0; lookDY = 0

        // 移动（相对朝向）
        let sin = sin(yaw), cos = cos(yaw)
        let speed: Float = 8 * dt
        let fx = -sin, fz = -cos, rx = cos, rz = -sin
        playerNode.position.x += (rx * moveX + fx * moveZ) * speed
        playerNode.position.z += (rz * moveX + fz * moveZ) * speed
        // 空气墙边界（到达边界才限制）
        let b = boundary - 2
        playerNode.position.x = min(b, max(-b, playerNode.position.x))
        playerNode.position.z = min(b, max(-b, playerNode.position.z))
        playerNode.eulerAngles.y = yaw

        // 相机（第一/第三人称）
        if camMode == .first {
            cameraNode.position = playerNode.position + SCNVector3(0, 1.7, 0)
            cameraNode.eulerAngles = SCNVector3(pitch, yaw, 0)
            gunNode.isHidden = false
        } else {
            let back = SCNVector3(-fx * 5, 2.6, -fz * 5)
            cameraNode.position = playerNode.position + back
            cameraNode.look(at: playerNode.position + SCNVector3(0, 1.4, 0))
            gunNode.isHidden = true
        }

        if fireHeld && CACurrentMediaTime() >= nextFire { fire() }
        if reloading { reloadTime -= dt; if reloadTime <= 0 { reloading = false; ammo = magSize; onHUD?() } }

        updateEnemies(dt: dt)
        if enemies.isEmpty { waveCheck() }
    }

    private func updateEnemies(dt: Float) {
        for e in enemies {
            let target = playerNode.position
            let dx = target.x - e.node.position.x
            let dz = target.z - e.node.position.z
            let dist = sqrt(dx * dx + dz * dz)
            let range: Float = (e.type == .brute) ? 3.0 : 2.0
            if dist > range {
                let sp: Float = (e.type == .runner) ? 6.5 : (e.type == .brute ? 2.2 : 3.4)
                let step = sp * dt
                e.node.position.x += dx / dist * step
                e.node.position.z += dz / dist * step
                e.node.eulerAngles.y = atan2(dx, dz)
            } else {
                e.attackT -= dt
                if e.attackT <= 0 {
                    e.attackT = 1.0
                    damagePlayer(e.type == .brute ? Int.random(in: 12...20) : Int.random(in: 6...12))
                }
            }
        }
    }

    private func damagePlayer(_ dmg: Int) {
        health -= dmg; if health < 0 { health = 0 }
        onHUD?()
        if health <= 0 { endGame(win: false) }
    }

    private func waveCheck() {
        if !enemies.isEmpty || !running { return }
        wave += 1
        if wave > maxWaves { endGame(win: true) } else { spawnWave(); onHUD?() }
    }

    private func endGame(win: Bool) {
        running = false; gameOver = true
        saveProgress()
        onGameOver?(win)
    }

    var isReloading: Bool { reloading }
}

enum EnemyType { case grunt, runner, brute }

final class Enemy {
    let node: SCNNode
    let type: EnemyType
    var attackT: Float = 0
    init(node: SCNNode, type: EnemyType) { self.node = node; self.type = type }

    static func makeNode(type: EnemyType) -> SCNNode {
        switch type {
        case .grunt:
            return makeHumanoid(scale: 1.0, main: UIColor(red: 0.4, green: 0.45, blue: 0.35, alpha: 1), gear: UIColor(red: 0.3, green: 0.32, blue: 0.26, alpha: 1))
        case .runner:
            return makeHumanoid(scale: 0.85, main: UIColor(red: 0.55, green: 0.4, blue: 0.3, alpha: 1), gear: UIColor(red: 0.4, green: 0.3, blue: 0.22, alpha: 1))
        case .brute:
            return makeHumanoid(scale: 1.5, main: UIColor(red: 0.25, green: 0.3, blue: 0.4, alpha: 1), gear: UIColor(red: 0.2, green: 0.22, blue: 0.3, alpha: 1))
        }
    }
}
