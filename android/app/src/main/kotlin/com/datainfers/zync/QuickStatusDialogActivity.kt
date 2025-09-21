package com.datainfers.zync

import android.app.Activity
import android.os.Bundle
import android.view.WindowManager
import android.app.AlertDialog

class QuickStatusDialogActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.widget.Toast.makeText(this, "QuickStatusDialogActivity abierta", android.widget.Toast.LENGTH_SHORT).show()
        // Hacer la ventana realmente transparente
        window.setFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        )
        window.setBackgroundDrawableResource(android.R.color.transparent)

        // Mostrar el modal personalizado (puedes reemplazarlo por tu propio layout)
        val emojis = arrayOf("👍", "🆘", "⏳", "✅", "🚶‍♂️")
        AlertDialog.Builder(this)
            .setTitle("Elige un estado rápido")
            .setItems(emojis) { dialogInterface, _ ->
                // Aquí deberías enviar el estado a Firebase según el emoji elegido
                // ...
                dialogInterface.dismiss()
                finish()
            }
            .setOnDismissListener { finish() }
            .show()
    }
}