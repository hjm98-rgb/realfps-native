import UIKit
import SceneKit

final class GameViewController: UIViewController {

    private var scnView: SCNView!
    private let game = Game()

    // UI
    private var menuView: UIView!
    private var storyView: UIView!
    private var hudView: UIView!
    private var overView: UIView!
    private var hpLabel: UILabel!
    private var ammoLabel: UILabel!
    private var killLabel: UILabel!
    private var waveLabel: UILabel!
    private var coinLabel: UILabel!
    private var camButton: UIButton!
    private var overTitle: UILabel!
    private var overDesc: UILabel!
    private var progressLabel: UILabel!

    // 触控
    private var joystickBase: UIView!
    private var joystickKnob: UIView!
    private var lookArea: UIView!
    private var fireButton: UIButton!
    private var reloadButton: UIButton!
    private var joystickCenter: CGPoint = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScene()
        setupUI()
        game.onHUD = { [weak self] in self?.refreshHUD() }
        game.onGameOver = { [weak self] win in self?.showGameOver(win) }
        refreshHUD()
    }

    private func setupScene() {
        scnView = SCNView(frame: view.bounds)
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.scene = game.scene
        scnView.delegate = game
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false
        scnView.isPlaying = true
        scnView.loops = true
        view.addSubview(scnView)
        game.setupScene()
    }

    // MARK: - UI
    private func setupUI() {
        hudView = UIView(frame: view.bounds)
        hudView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hudView.isHidden = true
        view.addSubview(hudView)

        hpLabel = makeLabel(fontSize: 15, color: .white)
        hpLabel.frame = CGRect(x: 18, y: view.bounds.height - 60, width: 200, height: 24)
        hudView.addSubview(hpLabel)

        ammoLabel = makeLabel(fontSize: 15, color: .white)
        ammoLabel.textAlignment = .right
        ammoLabel.frame = CGRect(x: view.bounds.width - 170, y: view.bounds.height - 60, width: 150, height: 24)
        hudView.addSubview(ammoLabel)

        killLabel = makeLabel(fontSize: 15, color: UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 1))
        killLabel.textAlignment = .center
        killLabel.frame = CGRect(x: 0, y: 16, width: view.bounds.width, height: 22)
        hudView.addSubview(killLabel)

        waveLabel = makeLabel(fontSize: 14, color: UIColor(red: 1, green: 0.8, blue: 0.6, alpha: 1))
        waveLabel.textAlignment = .center
        waveLabel.frame = CGRect(x: 0, y: 42, width: view.bounds.width, height: 20)
        hudView.addSubview(waveLabel)

        coinLabel = makeLabel(fontSize: 14, color: UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1))
        coinLabel.textAlignment = .right
        coinLabel.frame = CGRect(x: view.bounds.width - 170, y: 16, width: 150, height: 22)
        hudView.addSubview(coinLabel)

        // 第一/第三人称切换
        camButton = UIButton(type: .system)
        camButton.setTitle("第三人称", for: .normal)
        camButton.titleLabel?.font = .systemFont(ofSize: 13)
        camButton.setTitleColor(.white, for: .normal)
        camButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        camButton.layer.cornerRadius = 16
        camButton.frame = CGRect(x: 16, y: 16, width: 88, height: 34)
        camButton.addTarget(self, action: #selector(toggleCam), for: .touchUpInside)
        hudView.addSubview(camButton)

        let cross = UILabel(frame: CGRect(x: view.bounds.midX - 12, y: view.bounds.midY - 12, width: 24, height: 24))
        cross.text = "＋"; cross.textColor = .white; cross.textAlignment = .center; cross.font = .systemFont(ofSize: 20)
        hudView.addSubview(cross)

        buildTouchControls()

        // 主菜单（含存档显示）
        menuView = UIView(frame: view.bounds)
        menuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menuView.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 0.95)
        view.addSubview(menuView)

        let title = makeLabel(fontSize: 40, color: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1))
        title.text = "真实战场"; title.font = .boldSystemFont(ofSize: 40); title.textAlignment = .center
        title.frame = CGRect(x: 0, y: view.bounds.midY - 180, width: view.bounds.width, height: 56)
        menuView.addSubview(title)

        let sub = makeLabel(fontSize: 15, color: UIColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1))
        sub.text = "原生 3D 开放世界 FPS · 第一/第三人称"
        sub.textAlignment = .center
        sub.frame = CGRect(x: 0, y: view.bounds.midY - 120, width: view.bounds.width, height: 22)
        menuView.addSubview(sub)

        let start = UIButton(type: .system)
        start.setTitle("开始游戏", for: .normal)
        start.titleLabel?.font = .boldSystemFont(ofSize: 24)
        start.setTitleColor(.darkText, for: .normal)
        start.backgroundColor = UIColor(red: 1, green: 0.65, blue: 0.25, alpha: 1)
        start.layer.cornerRadius = 26
        start.frame = CGRect(x: view.bounds.midX - 110, y: view.bounds.midY - 40, width: 220, height: 54)
        start.addTarget(self, action: #selector(showStory), for: .touchUpInside)
        menuView.addSubview(start)

        progressLabel = makeLabel(fontSize: 13, color: .lightGray)
        progressLabel.numberOfLines = 2
        progressLabel.textAlignment = .center
        progressLabel.frame = CGRect(x: 40, y: view.bounds.midY + 30, width: view.bounds.width - 80, height: 46)
        menuView.addSubview(progressLabel)
        refreshProgress()

        let tip = makeLabel(fontSize: 12, color: .gray)
        tip.numberOfLines = 0
        tip.text = "左摇杆移动 · 右侧拖动视角 · 开火/换弹 · 可切换第一/第三人称\n开放世界无边界，空气墙在极远处"
        tip.textAlignment = .center
        tip.frame = CGRect(x: 40, y: view.bounds.midY + 90, width: view.bounds.width - 80, height: 46)
        menuView.addSubview(tip)

        // 背景故事
        storyView = UIView(frame: view.bounds)
        storyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        storyView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.88)
        storyView.isHidden = true
        view.addSubview(storyView)

        let sTitle = makeLabel(fontSize: 26, color: UIColor(red: 1, green: 0.65, blue: 0.25, alpha: 1))
        sTitle.text = "背景故事"
        sTitle.font = .boldSystemFont(ofSize: 26)
        sTitle.textAlignment = .center
        sTitle.frame = CGRect(x: 0, y: view.bounds.midY - 180, width: view.bounds.width, height: 40)
        storyView.addSubview(sTitle)

        let sText = makeLabel(fontSize: 15, color: .white)
        sText.numberOfLines = 0
        sText.text = "公元 2087 年，世界被黑暗军团攻陷。\n你是一名最后幸存的特种兵，被派往广阔的废土战场，\n击退一波又一波敌军，收复失地。\n\n战场上没有边界，空气墙只在你走到地图最远尽头时才会拦住你。\n活下去，击杀敌军，收集战利品，成为传说。"
        sText.textAlignment = .left
        sText.lineBreakMode = .byWordWrapping
        sText.frame = CGRect(x: 60, y: view.bounds.midY - 120, width: view.bounds.width - 120, height: 220)
        storyView.addSubview(sText)

        let go = UIButton(type: .system)
        go.setTitle("开始行动", for: .normal)
        go.titleLabel?.font = .boldSystemFont(ofSize: 22)
        go.setTitleColor(.darkText, for: .normal)
        go.backgroundColor = UIColor(red: 1, green: 0.65, blue: 0.25, alpha: 1)
        go.layer.cornerRadius = 26
        go.frame = CGRect(x: view.bounds.midX - 100, y: view.bounds.midY + 130, width: 200, height: 52)
        go.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        storyView.addSubview(go)

        // 结算
        overView = UIView(frame: view.bounds)
        overView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.72)
        overView.isHidden = true
        view.addSubview(overView)

        overTitle = makeLabel(fontSize: 38, color: .white)
        overTitle.textAlignment = .center
        overTitle.frame = CGRect(x: 0, y: view.bounds.midY - 130, width: view.bounds.width, height: 50)
        overView.addSubview(overTitle)

        overDesc = makeLabel(fontSize: 16, color: .lightGray)
        overDesc.numberOfLines = 2
        overDesc.textAlignment = .center
        overDesc.frame = CGRect(x: 30, y: view.bounds.midY - 70, width: view.bounds.width - 60, height: 46)
        overView.addSubview(overDesc)

        let again = UIButton(type: .system)
        again.setTitle("再来一局", for: .normal)
        again.titleLabel?.font = .boldSystemFont(ofSize: 22)
        again.setTitleColor(.darkText, for: .normal)
        again.backgroundColor = UIColor(red: 1, green: 0.65, blue: 0.25, alpha: 1)
        again.layer.cornerRadius = 26
        again.frame = CGRect(x: view.bounds.midX - 100, y: view.bounds.midY + 30, width: 200, height: 52)
        again.addTarget(self, action: #selector(restartGame), for: .touchUpInside)
        overView.addSubview(again)
    }

    private func buildTouchControls() {
        let w = view.bounds.width, h = view.bounds.height
        joystickBase = UIView(frame: CGRect(x: 30, y: h - 190, width: 140, height: 140))
        joystickBase.layer.cornerRadius = 70
        joystickBase.layer.borderWidth = 2
        joystickBase.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        joystickBase.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        hudView.addSubview(joystickBase)

        joystickKnob = UIView(frame: CGRect(x: 41, y: h - 179, width: 58, height: 58))
        joystickKnob.layer.cornerRadius = 29
        joystickKnob.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        hudView.addSubview(joystickKnob)
        joystickCenter = joystickKnob.center

        joystickBase.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(joystickMoved(_:))))

        lookArea = UIView(frame: CGRect(x: w * 0.42, y: 0, width: w * 0.58, height: h))
        hudView.addSubview(lookArea)
        lookArea.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(lookPanned(_:))))

        fireButton = UIButton(type: .system)
        fireButton.frame = CGRect(x: w - 130, y: h - 210, width: 104, height: 104)
        fireButton.layer.cornerRadius = 52
        fireButton.setTitle("开火", for: .normal)
        fireButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        fireButton.setTitleColor(.white, for: .normal)
        fireButton.backgroundColor = UIColor(red: 0.9, green: 0.25, blue: 0.15, alpha: 0.85)
        fireButton.addTarget(self, action: #selector(fireDown), for: .touchDown)
        fireButton.addTarget(self, action: #selector(fireUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        hudView.addSubview(fireButton)

        reloadButton = UIButton(type: .system)
        reloadButton.frame = CGRect(x: w - 80, y: h - 90, width: 60, height: 60)
        reloadButton.layer.cornerRadius = 30
        reloadButton.setTitle("换弹", for: .normal)
        reloadButton.titleLabel?.font = .systemFont(ofSize: 13)
        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        hudView.addSubview(reloadButton)
    }

    private func makeLabel(fontSize: CGFloat, color: UIColor) -> UILabel {
        let l = UILabel()
        l.font = .systemFont(ofSize: fontSize)
        l.textColor = color
        l.shadowColor = UIColor.black
        l.shadowOffset = CGSize(width: 0, height: 1)
        return l
    }

    // MARK: - 输入
    @objc private func joystickMoved(_ pan: UIPanGestureRecognizer) {
        let t = pan.translation(in: joystickBase)
        let maxR: CGFloat = 50
        var x = t.x / maxR, y = t.y / maxR
        let len = sqrt(x * x + y * y)
        if len > 1 { x /= len; y /= len }
        joystickKnob.center = CGPoint(x: joystickCenter.x + x * maxR, y: joystickCenter.y + y * maxR)
        game.setMove(Float(x), Float(-y))
        if pan.state == .ended || pan.state == .cancelled {
            joystickKnob.center = joystickCenter
            game.setMove(0, 0)
        }
    }
    @objc private func lookPanned(_ pan: UIPanGestureRecognizer) {
        let v = pan.velocity(in: lookArea)
        game.addLook(Float(v.x) * 0.0006, Float(v.y) * 0.0006)
    }
    @objc private func fireDown() { game.setFire(true) }
    @objc private func fireUp() { game.setFire(false) }
    @objc private func reloadTapped() { game.reload() }
    @objc private func toggleCam() { game.toggleCameraMode(); refreshHUD() }

    // MARK: - 流程
    @objc private func showStory() {
        menuView.isHidden = true
        storyView.isHidden = false
    }
    @objc private func startGame() {
        storyView.isHidden = true
        overView.isHidden = true
        hudView.isHidden = false
        game.start()
        refreshHUD()
    }
    @objc private func restartGame() {
        overView.isHidden = true
        hudView.isHidden = false
        game.start()
        refreshHUD()
    }

    private func refreshProgress() {
        let p = game.loadProgress()
        progressLabel.text = "存档：最高波次 \(p.bestWave) · 累计击杀 \(p.totalKills) · 金币 \(p.coins)"
    }

    private func refreshHUD() {
        guard isViewLoaded else { return }
        hpLabel?.text = "生命 \(game.health)"
        ammoLabel?.text = "\(game.ammo) / \(game.magSize)" + (game.isReloading ? " (换弹)" : "")
        killLabel?.text = "击杀 \(game.kills)"
        waveLabel?.text = "波次 \(game.wave)/\(game.maxWaves)"
        coinLabel?.text = "金币 \(game.coins)"
        camButton?.setTitle(game.camMode == .first ? "第三人称" : "第一人称", for: .normal)
    }

    private func showGameOver(_ win: Bool) {
        hudView.isHidden = true
        overView.isHidden = false
        overTitle.text = win ? "任务完成" : "你阵亡了"
        overDesc.text = win ? "你击退了全部 \(game.maxWaves) 波敌人\n数据已保存" : "本局击杀 \(game.kills) · 波次 \(game.wave) · 金币 \(game.coins)\n数据已保存"
        refreshProgress()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
}
