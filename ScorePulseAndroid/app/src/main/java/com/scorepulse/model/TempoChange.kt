package com.scorepulse.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Type of tempo transition for gradual tempo changes
 */
@Serializable
enum class TempoTransition {
    none,
    acc,  // accelerando
    rit   // ritardando
}

/**
 * Represents a tempo change at a specific bar
 */
@Serializable
data class TempoChange(
    @Serializable(with = UUIDSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val bar: Int,
    val tempo: Int? = null,
    val marking: String? = null,
    val transition: TempoTransition = TempoTransition.none
) {
    val displayText: String
        get() = when {
            tempo != null && marking != null -> "$marking (♩=$tempo)"
            tempo != null -> "♩=$tempo"
            transition == TempoTransition.acc -> "accel."
            transition == TempoTransition.rit -> "rit."
            else -> ""
        }
}
