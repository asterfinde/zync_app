package com.datainfers.zync

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Pre-warms the main Flutter engine at process start so that when MainActivity
 * is (re)created — e.g. after Android destroys the Activity while KeepAliveService
 * keeps the process alive — the engine is already running and no cold-start
 * splash is shown.
 */
class ZyncApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(MAIN_ENGINE_ID, engine)
    }

    companion object {
        const val MAIN_ENGINE_ID = "zync_main_engine"
    }
}
