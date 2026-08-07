package com.example.app_empaque

import android.app.Application
import android.content.Context

class EmpaqueApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initializeMlKit()
    }

    private fun initializeMlKit() {
        try {
            val mlKit = Class.forName("com.google.mlkit.common.MlKit")
            val initialize = mlKit.getMethod("initialize", Context::class.java)
            initialize.invoke(null, this)
        } catch (_: Throwable) {
            // ML Kit also registers its own provider; keep startup safe if API changes.
        }
    }
}
