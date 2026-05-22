package io.github.sanny32.omodscan_mobile

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BUILD_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPackageBuildDate" -> result.success(getString(R.string.omodscan_build_date_utc))
                    "getPackageVersion" -> result.success(packageVersion())
                    else -> result.notImplemented()
                }
            }
    }

    private fun packageVersion(): Map<String, Any> {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }

        return mapOf(
            "name" to (packageInfo.versionName ?: ""),
            "code" to versionCode,
        )
    }

    private companion object {
        const val BUILD_INFO_CHANNEL = "io.github.sanny32.omodscan_mobile/build_info"
    }
}
