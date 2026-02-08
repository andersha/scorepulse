package com.scorepulse.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Represents a bar with a time signature change.
 * Only bars with time signature changes need to be stored.
 */
@Serializable
data class Bar(
    @Serializable(with = UUIDSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val number: Int,
    val timeSignature: TimeSignature
)
