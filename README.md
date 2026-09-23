# 离线库存管理系统（手机端）APK 构建说明

纯本地离线库存 APP：商品档案 / 仓库货位 / 入库 / 出库 / 调拨 / 盘点 / 库存预警 / 备份恢复 / CSV导出，全部数据存储于手机本地 SQLite，无任何网络依赖。

## 方式一：云端自动构建（推荐，无需安装任何环境）

1. 将本目录（`app_flutter/`）推送到 GitHub 仓库（工作流文件已内置：`.github/workflows/build-apk.yml`）
2. 打开仓库 → **Actions** → 选择 **Build APK** → 自动开始构建
3. 构建完成后在该次运行页面底部 **Artifacts** 下载 `inventory-offline-apk`
4. 解压得到 `app-release.apk`，传到手机安装即可（需允许"安装未知来源应用"）

## 方式二：本地构建

环境要求：Flutter SDK（stable ≥ 3.16）+ Android SDK（Android Studio 自动附带）+ JDK 17

```bash
cd app_flutter
flutter create . --platforms=android --project-name inventory_offline
flutter pub get
flutter build apk --release
```

产物路径：`build/app/outputs/flutter-apk/app-release.apk`

真机调试：`flutter devices` 确认设备后运行 `flutter run --release`。

## iOS 说明

本工程按 Android（APK）交付。如需 iOS：安装 macOS + Xcode 后执行

```bash
flutter create . --platforms=ios
cd ios && pod install && cd ..
flutter build ios --release
```

并在 Xcode 中补充相机/相册权限描述（`Info.plist`：`NSCameraUsageDescription`、`NSPhotoLibraryUsageDescription`）。

## 常见问题

- **构建时插件版本冲突**：执行 `flutter clean` 后重试。
- **首次安装提示不安全**：APK 未做应用商店签名，属正常提示。
- **扫码不可用**：应用内所有扫码入口均提供「手动输入条码」兜底。
