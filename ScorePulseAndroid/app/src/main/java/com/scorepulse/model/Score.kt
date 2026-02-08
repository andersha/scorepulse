package com.scorepulse.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Represents a complete musical score
 */
@Serializable
data class Score(
    @Serializable(with = UUIDSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val title: String,
    val composer: String,
    val defaultTempo: Int,
    val tempoChanges: List<TempoChange> = emptyList(),
    val rehearsalMarks: List<RehearsalMark> = emptyList(),
    val bars: List<Bar>,
    val totalBars: Int
) {
    private val sortedTempoChanges = tempoChanges.sortedBy { it.bar }
    private val sortedRehearsalMarks = rehearsalMarks.sortedBy { it.bar }
    private val sortedBars = bars.sortedBy { it.number }

    /**
     * Get the time signature for a specific bar number
     */
    fun timeSignature(barNumber: Int): TimeSignature {
        val relevantBars = sortedBars.filter { it.number <= barNumber }
        return relevantBars.lastOrNull()?.timeSignature ?: TimeSignature.FOUR_FOUR
    }

    /**
     * Get the base tempo for a specific bar number (ignores transitions)
     */
    fun tempo(barNumber: Int): Int {
        val relevantChanges = sortedTempoChanges.filter { it.bar <= barNumber && it.tempo != null }
        return relevantChanges.lastOrNull()?.tempo ?: defaultTempo
    }

    /**
     * Get the tempo for a specific bar and beat position, accounting for gradual transitions
     */
    fun tempo(barNumber: Int, beatProgress: Double): Int {
        val transitionRange = findTransitionRange(barNumber)
        if (transitionRange != null) {
            val (startBar, endBar, startTempo, endTempo) = transitionRange
            val totalBars = endBar - startBar
            val barsCompleted = barNumber - startBar
            val overallProgress = (barsCompleted + beatProgress) / totalBars
            return (startTempo + (endTempo - startTempo) * overallProgress).toInt()
        }
        return tempo(barNumber)
    }

    private fun tempoBeforeTransition(barNumber: Int): Int {
        val previousChanges = sortedTempoChanges.filter { it.bar < barNumber && it.tempo != null }
        return previousChanges.lastOrNull()?.tempo ?: defaultTempo
    }

    private fun findTransitionRange(barNumber: Int): TransitionRange? {
        val transitionMarkers = sortedTempoChanges.filter { it.transition != TempoTransition.none }

        for (marker in transitionMarkers) {
            val endChange = sortedTempoChanges.firstOrNull { it.bar > marker.bar && it.tempo != null }
                ?: continue
            val endTempo = endChange.tempo ?: continue

            val startBar = marker.bar
            val endBar = endChange.bar

            if (barNumber >= startBar && barNumber < endBar) {
                val startTempo = tempoBeforeTransition(startBar)
                return TransitionRange(startBar, endBar, startTempo, endTempo)
            }
        }
        return null
    }

    /**
     * Check if a bar is in a tempo transition
     */
    fun isInTransition(barNumber: Int): Boolean {
        if (sortedTempoChanges.any { it.bar == barNumber && it.transition != TempoTransition.none }) {
            return true
        }
        return findTransitionRange(barNumber) != null
    }

    /**
     * Get the tempo marking for a specific bar number
     */
    fun tempoMarking(barNumber: Int): String? {
        val relevantChanges = sortedTempoChanges.filter { it.bar <= barNumber }
        return relevantChanges.lastOrNull()?.marking
    }

    /**
     * Get rehearsal mark at a specific bar, if any
     */
    fun rehearsalMark(barNumber: Int): RehearsalMark? {
        return sortedRehearsalMarks.firstOrNull { it.bar == barNumber }
    }

    /**
     * Get the next rehearsal mark after a given bar
     */
    fun nextRehearsalMark(barNumber: Int): RehearsalMark? {
        return sortedRehearsalMarks.firstOrNull { it.bar > barNumber }
    }

    /**
     * Get the previous rehearsal mark before a given bar
     */
    fun previousRehearsalMark(barNumber: Int): RehearsalMark? {
        return sortedRehearsalMarks.lastOrNull { it.bar < barNumber }
    }
}

private data class TransitionRange(
    val startBar: Int,
    val endBar: Int,
    val startTempo: Int,
    val endTempo: Int
)

/**
 * Container for loading multiple scores from JSON
 */
@Serializable
data class ScoreCollection(
    val scores: List<Score>
)
