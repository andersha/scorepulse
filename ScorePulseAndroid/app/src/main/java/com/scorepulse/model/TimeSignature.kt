package com.scorepulse.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonContentPolymorphicSerializer
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.util.UUID

object UUIDSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("UUID", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: UUID) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
}

/**
 * Represents a musical time signature
 */
@Serializable(with = TimeSignatureSerializer::class)
data class TimeSignature(
    val beatsPerBar: Int,
    val beatUnit: Int,
    val accentPattern: List<Int>? = null
) {
    companion object {
        val FOUR_FOUR = TimeSignature(4, 4)
        val THREE_FOUR = TimeSignature(3, 4)
        val TWO_FOUR = TimeSignature(2, 4)
        val FIVE_FOUR = TimeSignature(5, 4)
        val SIX_EIGHT = TimeSignature(6, 8)
        val NINE_EIGHT = TimeSignature(9, 8)
        val TWELVE_EIGHT = TimeSignature(12, 8)
        val FIVE_EIGHT = TimeSignature(5, 8, listOf(2, 3))
        val SEVEN_EIGHT = TimeSignature(7, 8, listOf(2, 2, 3))

        val COMMON = listOf(
            FOUR_FOUR, THREE_FOUR, TWO_FOUR, SIX_EIGHT,
            FIVE_FOUR, FIVE_EIGHT, SEVEN_EIGHT, NINE_EIGHT, TWELVE_EIGHT
        )

        fun fromString(s: String): TimeSignature? {
            val parts = s.split("/")
            if (parts.size != 2) return null
            val beats = parts[0].toIntOrNull() ?: return null
            val unit = parts[1].toIntOrNull() ?: return null
            return TimeSignature(beats, unit)
        }
    }

    val isCompound: Boolean
        get() = beatUnit == 8 && beatsPerBar % 3 == 0

    val isSixteenthBased: Boolean
        get() = beatUnit == 16

    val hasAccentPattern: Boolean
        get() = !accentPattern.isNullOrEmpty()

    val defaultAccentPattern: List<Int>?
        get() {
            if (beatUnit != 8) return null
            return if (beatsPerBar % 3 == 0) {
                val groupCount = beatsPerBar / 3
                List(groupCount) { 3 }
            } else {
                val pattern = mutableListOf<Int>()
                var remaining = beatsPerBar
                while (remaining > 0) {
                    if (remaining == 3 || remaining == 2) {
                        pattern.add(remaining)
                        remaining = 0
                    } else {
                        pattern.add(2)
                        remaining -= 2
                    }
                }
                pattern
            }
        }

    val effectiveAccentPattern: List<Int>?
        get() = if (beatUnit == 16) accentPattern else (accentPattern ?: defaultAccentPattern)

    val hasGroupings: Boolean
        get() = effectiveAccentPattern != null

    val actualBeatsPerBar: Int
        get() = effectiveAccentPattern?.size ?: beatsPerBar

    fun accentPositions(): List<Int> {
        val pattern = effectiveAccentPattern ?: return listOf(0)
        val positions = mutableListOf(0)
        var currentPosition = 0
        for (i in 0 until pattern.size - 1) {
            currentPosition += pattern[i]
            positions.add(currentPosition)
        }
        return positions
    }

    val displayString: String
        get() = "$beatsPerBar/$beatUnit"
}

object TimeSignatureSerializer : JsonContentPolymorphicSerializer<TimeSignature>(TimeSignature::class) {
    override fun selectDeserializer(element: JsonElement) = when (element) {
        is JsonPrimitive -> TimeSignatureStringSerializer
        is JsonObject -> TimeSignatureObjectSerializer
        else -> throw IllegalArgumentException("Unknown TimeSignature format")
    }
}

object TimeSignatureStringSerializer : KSerializer<TimeSignature> {
    override val descriptor = PrimitiveSerialDescriptor("TimeSignature", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: TimeSignature) = encoder.encodeString(value.displayString)
    override fun deserialize(decoder: Decoder): TimeSignature {
        return TimeSignature.fromString(decoder.decodeString())
            ?: throw IllegalArgumentException("Invalid time signature format")
    }
}

@Serializable
private data class TimeSignatureObject(
    val timeSignature: String,
    val accentPattern: List<Int>? = null
)

object TimeSignatureObjectSerializer : KSerializer<TimeSignature> {
    override val descriptor = TimeSignatureObject.serializer().descriptor
    override fun serialize(encoder: Encoder, value: TimeSignature) {
        val obj = TimeSignatureObject(value.displayString, value.accentPattern)
        encoder.encodeSerializableValue(TimeSignatureObject.serializer(), obj)
    }
    override fun deserialize(decoder: Decoder): TimeSignature {
        val obj = decoder.decodeSerializableValue(TimeSignatureObject.serializer())
        val base = TimeSignature.fromString(obj.timeSignature)
            ?: throw IllegalArgumentException("Invalid time signature: ${obj.timeSignature}")
        return TimeSignature(base.beatsPerBar, base.beatUnit, obj.accentPattern)
    }
}
