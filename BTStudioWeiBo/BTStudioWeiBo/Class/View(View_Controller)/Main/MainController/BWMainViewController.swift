//
//  BWMainViewController.swift
//  BTStudioWeiBo
//
//  Created by hadlinks on 2019/3/30.
//  Copyright © 2019 BTStudio. All rights reserved.
//

import UIKit
import SVProgressHUD

/// 主控制器
class BWMainViewController: UITabBarController {
    
    /// 定时器,用来定期检查新微博的数量
    private var timer: Timer?
    
    
    deinit {
        timer?.invalidate()
        
        // 注销通知
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupChildControllers()
        setupComposeButton()
        setupTimer()
        setupNewFeatureViews()
        
        delegate = self
        
        // 注册通知
        NotificationCenter.default.addObserver(self, selector: #selector(userLogin(notification:)), name: NSNotification.Name(rawValue: BWUserShouldLoginNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userRegister(notification:)), name: NSNotification.Name(rawValue: BWUserShouldRegisterNotification), object: nil)
    }
    
    /// 使用代码控制设备的方向
    ///
    /// 设置支持的方向之后,当前的控制器及其子控制器都会遵守这个方向!
    ///
    /// 如果是视频播放,通常通过 modal 推出控制器!
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    
    // MARK: - 监听方法
    
    /// 用户登录
    ///
    /// - Parameter notification: 登录通知
    @objc private func userLogin(notification: Notification) {
        let object = notification.object as? String
        
        var when = DispatchTime.now()
        
        if object != nil {
            // 设置指示器渐变方式
            SVProgressHUD.setDefaultMaskType(.gradient)
            SVProgressHUD.showInfo(withStatus: "用户登录已超时，请重新登录")
            
            // 调整延迟时间
            when = DispatchTime.now() + 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: when) {
            SVProgressHUD.setDefaultMaskType(.clear)
            
            let nav = UINavigationController(rootViewController: BWOAuthViewController())
            self.present(nav, animated: true, completion: nil)
        }
    }
    
    /// 用户注册
    ///
    /// - Parameter notification: 注册通知
    @objc private func userRegister(notification: Notification) {
//        print("用户注册通知: \(notification)")
        let nav = UINavigationController(rootViewController: BWRegisterViewController())
        present(nav, animated: true, completion: nil)
    }
    
    /// 点击了撰写按钮
    ///
    /**
      private 保证方法私有,仅在当前对象里能被访问
      @objc 允许方法在'运行时'通过OC的消息机制被调用
     */
    @objc private func composeStatus() {
        // 1. 判断是否已登录
        
        // 2.
        // 2.1 实例化视图
        let composeTypeView = BWComposeTypeView.composeTypeView()
        
        // 2.2 显示视图
        // 需要解决循环引用问题
        composeTypeView.show { [weak composeTypeView] (clsName) in
            // 类名->类 的转换
            guard let clsName = clsName,
                let cls = NSClassFromString(Bundle.main.namespace + "." + clsName) as? BWComposeViewController.Type else {
                // 移除视图
                composeTypeView?.removeFromSuperview()
                return
            }
            
            let vc = cls.init()
            let nav = BWNavigationController(rootViewController: vc)
            
            // 强行更新约束 - 会直接更新所有子视图的约束!
            nav.view.layoutIfNeeded()
            /**
             * 提示: 开发中如果发现不希望的布局约束和动画混在一起,应该向前寻找,强制更新约束!
             */
            
            self.present(nav, animated: true) {
                // 移除视图
                composeTypeView?.removeFromSuperview()
            }
        }
    }
    
    
    // MARK: - 私有控件
    private lazy var composeButton: UIButton = UIButton.cz_imageButton("tabbar_compose_icon_add", backgroundImageName: "tabbar_compose_button")
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}


// MARK: - UITabBarControllerDelegate
extension BWMainViewController: UITabBarControllerDelegate {
    
    /// 将要选择 TabBarItem
    ///
    /// - Parameters:
    ///   - tabBarController: tabBarController
    ///   - viewController: 目标控制器
    /// - Returns: 是否切换到目标控制器
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        print("将要切换到: \(viewController)")
        
        // 获取目标控制器在数组中的索引
        let index = viewControllers?.firstIndex(of: viewController)
        
        // 判断当前索引是否为0,为0表示在首页,同时判断目标控制器索引是否为首页,
        // 如果当前索引为首页,目标索引也为首页,则刷新
        if selectedIndex == 0 && index == selectedIndex {
            print("刷新首页..............")
            // 刷新首页数据
            let nav = viewController as! BWNavigationController
            let vc = nav.viewControllers.first as! BWHomeViewController
            
            vc.tableView?.setContentOffset(CGPoint(x: 0, y: -NavBarHeight), animated: true)
            // 增加延迟是为了保证表格先滚动到顶部,然后再刷新整个表格
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                vc.loadData()
            }
            
            // 清除tabBarItem和App的badgeNumber
            vc.tabBarItem.badgeValue = nil
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        // 判断目标控制器是否为UIViewController,如果是,说明点击了撰写按钮,则不切换
        return !viewController.isMember(of: UIViewController.self)
    }
    
    /// 已选择 TabBarItem
    ///
    /// - Parameters:
    ///   - tabBarController: tabBarController
    ///   - viewController: 已选择的控制器
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        
    }
}


// MARK: - 定时器相关方法
extension BWMainViewController {
    private func setupTimer() {
        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    /// 定时器触发方法
    @objc private func updateTimer() {
        if !BWNetworkManager.shared.userLogon {
            return
        }
        
        BWNetworkManager.shared.unreadCount { (count) in
            print("有 \(count) 条未读微博!")
            // 设置首页tabBarItem的badgeNumber
            self.tabBar.items?.first?.badgeValue = count > 0 ? "\(count)" : nil
            
            // 设置App的badgeNumber (从iOS 8.0之后,要用户授权后才能显示)
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
}


// extension类似于OC中的分类,它还可以用来切分代码块
// 可以把相近功能的函数放在一个extension中,便于代码的维护
// 注意: 和OC的分类一样,extension中不能定义属性
// MARK: - 设置界面
extension BWMainViewController {
    /// 添加撰写按钮
    private func setupComposeButton() {
        tabBar.addSubview(composeButton)
        
        // 计算按钮的宽度
        let count = viewControllers?.count ?? 0
        // - 1 是为了把按钮的宽度变大一点,以消除按钮之间容错点的影响
        let w = tabBar.frame.width / CGFloat(count) - 1
        
        // 缩进 (OC中为CGRectInset, 正数表示向内缩进,负数表示向外扩展)
        composeButton.frame = tabBar.bounds.insetBy(dx: 2 * w, dy: 0)
        
        // 添加监听方法
        composeButton.addTarget(self, action: #selector(composeStatus), for: .touchUpInside)
    }
    
    /// 设置所有子控件器
    private func setupChildControllers() {
        
        // 0. 获取沙盒的json文件路径
        let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jsonPath = docDir.appendingFormat("/%@", "Main.json")
        var jsonData = NSData(contentsOfFile: jsonPath)
        
        // 判断jsonData是否为空,如果为空,说明本地沙盒中没有json文件,则从bundle中加载配置json
        if jsonData == nil {
            let path = Bundle.main.path(forResource: "Main", ofType: "json")
            jsonData = NSData(contentsOfFile: path!)
        }
        
        // [⚠️- 谨记知识点 -⚠️]
        /**
         * try的含义:
         * throws 表示会抛出异常
         *
         * 1. 方法一(推荐) try? (弱try),如果解析成功,就有值;否则为nil
         *    let array = try? JSONSerialization.jsonObject(with: , options: )
         *
         * 2. 方法二(不推荐) try! (强try),如果解析成功,就有值;否则会崩溃
         *    let array = try! JSONSerialization.jsonObject(with: , options: )
         *
         * 3. 方法三(不推荐) try 处理异常,能够接收到错误,并且输出错误
         *    do {
         *        let array = try JSONSerialization.jsonObject(with: , options: )
         *    } catch {
         *        print(error)
         *    }
         *
         * 小知识: OC中有人用 try catch吗? 为什么?
         * ARC开发环境下,编译器会自动添加 retain / release / autorelease,
         * 如果用try catch,一旦出现不平衡,就会造成内存泄漏!
         */
        // 此时,jsonData一定会有值,则进行反序列化
        guard let array = try? JSONSerialization.jsonObject(with: jsonData! as Data, options: []) as? [[String: Any]] else {
            return
        }
        
        
        // 1. 从bundle加载配置json,并解析为数组
//        guard let path = Bundle.main.path(forResource: "Main", ofType: "json"),
//            let data = NSData(contentsOfFile: path),
//            let array = try? JSONSerialization.jsonObject(with: data as Data, options: []) as? [[String: Any]] else {
//            return
//        }
        
        
        
        // 在现在的很多流行App中,界面的创建都依赖于网络的json
//        let array: [[String: Any]] = [
//            ["clsName": "BWHomeViewController",
//             "title": "首页",
//             "imageName": "home",
//             "visitorInfo": ["imageName": "", "message": "关注一些人，回这里看看有什么惊喜"]
//            ],
//
//            ["clsName": "BWMessageViewController",
//             "title": "消息",
//             "imageName": "message_center",
//             "visitorInfo": ["imageName": "visitordiscover_image_message", "message": "登录后，别人评论你的微博，发给你的消息，都会在这里收到通知"]
//            ],
//
//            ["clsName": "UIViewController"], // 占位tabBar
//
//            ["clsName": "BWDiscoveryViewController",
//             "title": "发现",
//             "imageName": "discover",
//             "visitorInfo": ["imageName": "visitordiscover_image_message", "message": "登录后，最新、最热微博尽在掌握，不再会与实事潮流擦肩而过"]
//            ],
//
//            ["clsName": "BWProfileViewController",
//             "title": "我的",
//             "imageName": "profile",
//             "visitorInfo": ["imageName": "visitordiscover_image_profile", "message": "登录后，你的微博、相册、个人资料会显示在这里，展示给别人"]
//            ]
//        ]
        
        // 数组写入plist文件,用来测试数据格式是否正确,转换成plist后查看数据时会更加直观
//        (array as NSArray).write(toFile: "/Users/hadlinks/Desktop/Demo.plist", atomically: true)
        
        // 数组 -> json (序列化)
//        let jsonData = try! JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted])
//        let fileURL = URL(fileURLWithPath: "/Users/hadlinks/Desktop/Demo.json")
//        try! jsonData.write(to: fileURL)
        
        
        // 2. 遍历数组,循环创建控制器数组
        var controllers: [UIViewController] = []
        for dict in array {
            controllers.append(controller(dict: dict))
        }
        
        viewControllers = controllers
    }
    
    /// 使用字典创建一个子控制器
    ///
    /// - Parameter dict: 信息字典 ["clsName": , "title": , "imageName": , "visitorInfo": ]
    /// - Returns: 子控制器
    private func controller(dict: [String: Any]) -> UIViewController {
        // 1. 取得字典内容
        guard let className = dict["clsName"] as? String,
            let title = dict["title"] as? String,
            let imageName = dict["imageName"] as? String,
            // 将className转换成class
            let cls = NSClassFromString(Bundle.main.namespace + "." + className) as? BWBaseViewController.Type,
            let visitorDictionary = dict["visitorInfo"] as? [String: String]
        else {
                return UIViewController()
        }
        
        // 2. 创建视图控制器
        let vc = cls.init()
        vc.title = title
        
        // 设置控制器的访客视图信息字典
        vc.visitorInfoDictionary = visitorDictionary
        
        // 设置TabBar图标
        vc.tabBarItem.image = UIImage(named: "tabbar_" + imageName)?.withRenderingMode(.alwaysOriginal)
        vc.tabBarItem.selectedImage = UIImage(named: "tabbar_" + imageName + "_selected")?.withRenderingMode(.alwaysOriginal)
        
        // 设置TabBar标题颜色和字体
        vc.tabBarItem.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: RGBColor(51, 51, 51)], for: .selected)
        // 系统默认字体大小是12,若要修改字体大小,则需要在Normal状态下修改
        vc.tabBarItem.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13.5)], for: .normal)
        
        // 实例化导航控制器的时候,会调用push方法将rootVC压栈
        let nav = BWNavigationController(rootViewController: vc)
        return nav
    }
}


// MARK: - 新特性相关
extension BWMainViewController {
    
    /// 是否新版本
    ///
    /// extension中可以有计算型属性,它不会占用存储空间
    private var isNewVersion: Bool {
        // 1. 当前版本
        let currentVersion = Bundle.main.appVersion
        
        // 2. 老版本
        let path = ("AppVersion" as NSString).cz_appendDocumentDir() ?? ""
        let oldVersion = try? String(contentsOfFile: path)
        
        // 3. 将当前版本号存储起来
        try? currentVersion.write(to: URL(fileURLWithPath: path, isDirectory: true), atomically: true, encoding: .utf8)
        
        // 4. 版本比较
        return currentVersion != oldVersion
    }
    
    /// 设置新特性视图
    private func setupNewFeatureViews() {
        // 1. 判断是否登录
        if !BWNetworkManager.shared.userLogon {
            return
        }
        // 2. 检查版本是否更新 如果更新,显示新特性,否则显示欢迎视图
        let view1 = isNewVersion ? BWNewFeatureView.newFeatureView() : BWWelcomeView.welcomeView()
        view1.frame = view.bounds
        // 3. 添加视图
        view.addSubview(view1)
    }
}

