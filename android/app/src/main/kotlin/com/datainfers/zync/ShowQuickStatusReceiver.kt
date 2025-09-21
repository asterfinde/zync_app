package com.datainfers.zync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ShowQuickStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val modalIntent = Intent(context, QuickStatusDialogActivity::class.java)
        modalIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(modalIntent)
    }
}
