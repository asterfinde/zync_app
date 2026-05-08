package com.datainfers.zync

/**
 * IDs canónicos de estado de presencia.
 *
 * IMPORTANTE: cualquier cambio aquí debe reflejarse en
 * lib/contexts/presence/domain/value_objects/status_id.dart
 *
 * Los IDs deben coincidir exactamente con los valores en Firestore.
 */
object StatusIds {
    const val FINE             = "fine"
    const val HOME             = "home"
    const val SCHOOL           = "school"
    const val WORK             = "work"
    const val UNIVERSITY       = "university"
    const val SOS              = "sos"
    const val DO_NOT_DISTURB   = "do_not_disturb"
    const val PUBLIC_TRANSPORT = "public_transport"
}
