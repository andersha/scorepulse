package com.scorepulse.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Represents a rehearsal mark at a specific bar
 */
@Serializable
data class RehearsalMark(
    @Serializable(with = UUIDSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val bar: Int
) {
    val displayText: String
        get() = "[$name]"
}
