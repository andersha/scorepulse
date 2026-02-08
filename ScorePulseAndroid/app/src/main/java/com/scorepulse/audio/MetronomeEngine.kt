package com.scorepulse.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import com.scorepulse.model.Score
import com.scorepulse.model.SubdivisionMode
import com.scorepulse.model.TimeSignature
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.PI
import kotlin.math.sin

/**
 * Audio engine for metronome click generation using AudioTrack.
 * Uses low-latency configuration and syncs UI updates with audio playback.
 */
class MetronomeEngine {
    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _currentBeat = MutableStateFlow(1)
    val currentBeat: StateFlow<Int> = _currentBeat.asStateFlow()

    private val _currentBar = MutableStateFlow(1)
    val currentBar: StateFlow<Int> = _currentBar.asStateFlow()

    private val sampleRate = 44100
    private var audioTrack: AudioTrack? = null
    private var playbackJob: Job? = null

    // Click duration in milliseconds
    private val clickDurationMs = 50
    private val clickSamples = (sampleRate * clickDurationMs / 1000)

    private enum class ClickType(val frequency: Float) {
        DOWNBEAT(1200f),
        BEAT_ACCENT(1000f),
        OFFBEAT(800f)
    }

    /**
     * Generate just the click sound (short duration)
     */
    private fun generateClick(type: ClickType): ShortArray {
        val samples = ShortArray(clickSamples)
        val frequency = type.frequency
        val twoPi = 2.0 * PI

        for (i in 0 until clickSamples) {
            val time = i.toDouble() / sampleRate
            val envelope = 1.0 - (i.toDouble() / clickSamples)
            val sample = sin(twoPi * frequency * time) * envelope * 0.5
            samples[i] = (sample * Short.MAX_VALUE).toInt().toShort()
        }
        return samples
    }

    /**
     * Generate silence for a given duration
     */
    private fun generateSilence(durationMs: Double): ShortArray {
        val totalSamples = (sampleRate * durationMs / 1000.0).toInt()
        return ShortArray(totalSamples) // All zeros = silence
    }

    private fun createAudioTrack(): AudioTrack {
        val bufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
    }

    /**
     * Start simple metronome with fixed tempo and time signature
     */
    fun startMetronome(bpm: Int, timeSignature: TimeSignature, subdivision: SubdivisionMode) {
        stop()

        playbackJob = CoroutineScope(Dispatchers.Default).launch {
            val track = createAudioTrack()
            audioTrack = track
            track.play()
            
            withContext(Dispatchers.Main) {
                _isPlaying.value = true
                _currentBeat.value = 1
                _currentBar.value = 1
            }

            val isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
            val isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
            val actualBeats = timeSignature.actualBeatsPerBar

            val quarterNoteDurationMs = 60000.0 / bpm
            val eighthNoteDurationMs = quarterNoteDurationMs / 2.0
            val sixteenthNoteDurationMs = quarterNoteDurationMs / 4.0

            val totalClicksPerBar = when (subdivision) {
                SubdivisionMode.QUARTER -> actualBeats
                SubdivisionMode.EIGHTH -> when {
                    isSixteenth -> actualBeats
                    isGroupedEighth -> timeSignature.beatsPerBar
                    else -> actualBeats * 2
                }
            }

            // Pre-generate click sounds
            val downbeatClick = generateClick(ClickType.DOWNBEAT)
            val accentClick = generateClick(ClickType.BEAT_ACCENT)
            val offbeatClick = generateClick(ClickType.OFFBEAT)

            var clickIndex = 0
            var currentBarNum = 1

            while (isActive) {
                val positionInBar = clickIndex % totalClicksPerBar

                // Determine click type
                val clickType = when {
                    isSixteenth || (timeSignature.hasGroupings && subdivision == SubdivisionMode.QUARTER) ->
                        if (positionInBar == 0) ClickType.DOWNBEAT else ClickType.OFFBEAT
                    subdivision == SubdivisionMode.EIGHTH -> when {
                        positionInBar == 0 -> ClickType.DOWNBEAT
                        timeSignature.hasGroupings -> {
                            val positions = timeSignature.accentPositions()
                            if (positions.contains(positionInBar)) ClickType.BEAT_ACCENT else ClickType.OFFBEAT
                        }
                        else -> if (positionInBar % 2 == 0) ClickType.BEAT_ACCENT else ClickType.OFFBEAT
                    }
                    else -> if (positionInBar == 0) ClickType.DOWNBEAT else ClickType.OFFBEAT
                }

                // Calculate beat number for UI
                val beatNumber = when {
                    isSixteenth || (isGroupedEighth && subdivision == SubdivisionMode.QUARTER) ->
                        positionInBar + 1
                    isGroupedEighth && subdivision == SubdivisionMode.EIGHTH -> {
                        val accentPositions = timeSignature.accentPositions()
                        var beatNum = 1
                        for ((idx, pos) in accentPositions.withIndex()) {
                            if (positionInBar >= pos) beatNum = idx + 1
                        }
                        beatNum
                    }
                    subdivision == SubdivisionMode.QUARTER -> positionInBar + 1
                    else -> (positionInBar / 2) + 1
                }

                // Calculate duration for this beat
                val beatDurationMs = when {
                    isSixteenth -> {
                        val pattern = timeSignature.effectiveAccentPattern
                        if (pattern != null) sixteenthNoteDurationMs * pattern[positionInBar]
                        else sixteenthNoteDurationMs
                    }
                    isGroupedEighth && subdivision == SubdivisionMode.QUARTER -> {
                        val pattern = timeSignature.effectiveAccentPattern
                        if (pattern != null) eighthNoteDurationMs * pattern[positionInBar]
                        else eighthNoteDurationMs
                    }
                    subdivision == SubdivisionMode.EIGHTH -> {
                        if (isGroupedEighth) eighthNoteDurationMs
                        else quarterNoteDurationMs / 2.0
                    }
                    else -> quarterNoteDurationMs
                }

                // Select pre-generated click
                val clickSamples = when (clickType) {
                    ClickType.DOWNBEAT -> downbeatClick
                    ClickType.BEAT_ACCENT -> accentClick
                    ClickType.OFFBEAT -> offbeatClick
                }

                // Write click - this triggers audio playback
                track.write(clickSamples, 0, clickSamples.size)
                
                // Update UI immediately after click is written (closer to actual sound)
                withContext(Dispatchers.Main) {
                    _currentBar.value = currentBarNum
                    _currentBeat.value = beatNumber
                }

                // Write silence for the rest of the beat duration
                val silenceDurationMs = beatDurationMs - clickDurationMs
                if (silenceDurationMs > 0) {
                    val silenceSamples = generateSilence(silenceDurationMs)
                    track.write(silenceSamples, 0, silenceSamples.size)
                }

                clickIndex++
                if (clickIndex % totalClicksPerBar == 0) {
                    currentBarNum++
                }
            }
        }
    }

    /**
     * Start score playback with changing time signatures and tempi
     */
    fun startScorePlayback(
        score: Score,
        startBar: Int,
        tempoMultiplier: Double,
        subdivision: SubdivisionMode,
        countIn: Boolean = false,
        onPositionUpdate: (bar: Int, beat: Int, tempo: Int) -> Unit
    ) {
        stop()

        playbackJob = CoroutineScope(Dispatchers.Default).launch {
            val track = createAudioTrack()
            audioTrack = track
            track.play()
            
            withContext(Dispatchers.Main) {
                _isPlaying.value = true
            }

            // Pre-generate click sounds
            val downbeatClick = generateClick(ClickType.DOWNBEAT)
            val accentClick = generateClick(ClickType.BEAT_ACCENT)
            val offbeatClick = generateClick(ClickType.OFFBEAT)

            // Play count-in if enabled
            if (countIn) {
                playCountIn(track, downbeatClick, offbeatClick, score, startBar, tempoMultiplier, subdivision, onPositionUpdate)
            }

            var barNumber = startBar

            while (barNumber <= score.totalBars && isActive) {
                val timeSignature = score.timeSignature(barNumber)
                val isInTransition = score.isInTransition(barNumber)

                val isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
                val isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
                val actualBeats = timeSignature.actualBeatsPerBar

                val totalClicksPerBar = when (subdivision) {
                    SubdivisionMode.QUARTER -> actualBeats
                    SubdivisionMode.EIGHTH -> when {
                        isSixteenth -> actualBeats
                        isGroupedEighth -> timeSignature.beatsPerBar
                        else -> actualBeats * 2
                    }
                }

                for (clickIndex in 0 until totalClicksPerBar) {
                    if (!isActive) break

                    val beatProgress = clickIndex.toDouble() / totalClicksPerBar

                    val baseTempo = if (isInTransition) {
                        score.tempo(barNumber, beatProgress)
                    } else {
                        score.tempo(barNumber)
                    }
                    val effectiveTempo = (baseTempo * tempoMultiplier).toInt()

                    val quarterNoteDurationMs = 60000.0 / effectiveTempo
                    val eighthNoteDurationMs = quarterNoteDurationMs / 2.0
                    val sixteenthNoteDurationMs = quarterNoteDurationMs / 4.0

                    // Determine click type
                    val clickType = when {
                        isSixteenth || (timeSignature.hasGroupings && subdivision == SubdivisionMode.QUARTER) ->
                            if (clickIndex == 0) ClickType.DOWNBEAT else ClickType.OFFBEAT
                        subdivision == SubdivisionMode.EIGHTH -> when {
                            clickIndex == 0 -> ClickType.DOWNBEAT
                            timeSignature.hasGroupings -> {
                                val positions = timeSignature.accentPositions()
                                if (positions.contains(clickIndex)) ClickType.BEAT_ACCENT else ClickType.OFFBEAT
                            }
                            else -> if (clickIndex % 2 == 0) ClickType.BEAT_ACCENT else ClickType.OFFBEAT
                        }
                        else -> if (clickIndex == 0) ClickType.DOWNBEAT else ClickType.OFFBEAT
                    }

                    // Calculate beat number
                    val beatNumber = when {
                        isSixteenth || (isGroupedEighth && subdivision == SubdivisionMode.QUARTER) ->
                            clickIndex + 1
                        isGroupedEighth && subdivision == SubdivisionMode.EIGHTH -> {
                            val accentPositions = timeSignature.accentPositions()
                            var beatNum = 1
                            for ((idx, pos) in accentPositions.withIndex()) {
                                if (clickIndex >= pos) beatNum = idx + 1
                            }
                            beatNum
                        }
                        subdivision == SubdivisionMode.QUARTER -> clickIndex + 1
                        else -> (clickIndex / 2) + 1
                    }

                    // Calculate duration
                    val beatDurationMs = when {
                        isSixteenth -> {
                            val pattern = timeSignature.effectiveAccentPattern
                            if (pattern != null) sixteenthNoteDurationMs * pattern[clickIndex]
                            else sixteenthNoteDurationMs
                        }
                        isGroupedEighth && subdivision == SubdivisionMode.QUARTER -> {
                            val pattern = timeSignature.effectiveAccentPattern
                            if (pattern != null) eighthNoteDurationMs * pattern[clickIndex]
                            else eighthNoteDurationMs
                        }
                        subdivision == SubdivisionMode.EIGHTH -> {
                            if (isGroupedEighth) eighthNoteDurationMs
                            else quarterNoteDurationMs / 2.0
                        }
                        else -> quarterNoteDurationMs
                    }

                    // Select click
                    val clickSamples = when (clickType) {
                        ClickType.DOWNBEAT -> downbeatClick
                        ClickType.BEAT_ACCENT -> accentClick
                        ClickType.OFFBEAT -> offbeatClick
                    }

                    // Write click
                    track.write(clickSamples, 0, clickSamples.size)

                    // Update UI after click is written
                    withContext(Dispatchers.Main) {
                        _currentBar.value = barNumber
                        _currentBeat.value = beatNumber
                        onPositionUpdate(barNumber, beatNumber, effectiveTempo)
                    }

                    // Write silence for remaining duration
                    val silenceDurationMs = beatDurationMs - clickDurationMs
                    if (silenceDurationMs > 0) {
                        val silenceSamples = generateSilence(silenceDurationMs)
                        track.write(silenceSamples, 0, silenceSamples.size)
                    }
                }

                barNumber++
            }

            withContext(Dispatchers.Main) {
                _isPlaying.value = false
            }
        }
    }

    private suspend fun playCountIn(
        track: AudioTrack,
        downbeatClick: ShortArray,
        offbeatClick: ShortArray,
        score: Score,
        startBar: Int,
        tempoMultiplier: Double,
        subdivision: SubdivisionMode,
        onPositionUpdate: (bar: Int, beat: Int, tempo: Int) -> Unit
    ) {
        val timeSignature = score.timeSignature(startBar)
        val baseTempo = score.tempo(startBar)
        val effectiveTempo = (baseTempo * tempoMultiplier).toInt()

        val quarterNoteDurationMs = 60000.0 / effectiveTempo
        val eighthNoteDurationMs = quarterNoteDurationMs / 2.0
        val sixteenthNoteDurationMs = quarterNoteDurationMs / 4.0

        val isGroupedEighth = timeSignature.hasGroupings && timeSignature.beatUnit == 8
        val isSixteenth = timeSignature.isSixteenthBased && timeSignature.hasGroupings
        val actualBeats = timeSignature.actualBeatsPerBar

        val totalClicksPerBar = when (subdivision) {
            SubdivisionMode.QUARTER -> actualBeats
            SubdivisionMode.EIGHTH -> when {
                isSixteenth -> actualBeats
                isGroupedEighth -> timeSignature.beatsPerBar
                else -> actualBeats * 2
            }
        }

        for (clickIndex in 0 until totalClicksPerBar) {
            val clickSamples = if (clickIndex == 0) downbeatClick else offbeatClick

            val beatNumber = when {
                isSixteenth || (isGroupedEighth && subdivision == SubdivisionMode.QUARTER) ->
                    clickIndex + 1
                isGroupedEighth && subdivision == SubdivisionMode.EIGHTH -> {
                    val accentPositions = timeSignature.accentPositions()
                    var beatNum = 1
                    for ((idx, pos) in accentPositions.withIndex()) {
                        if (clickIndex >= pos) beatNum = idx + 1
                    }
                    beatNum
                }
                subdivision == SubdivisionMode.QUARTER -> clickIndex + 1
                else -> (clickIndex / 2) + 1
            }

            val beatDurationMs = when {
                isSixteenth -> {
                    val pattern = timeSignature.effectiveAccentPattern
                    if (pattern != null) sixteenthNoteDurationMs * pattern[clickIndex]
                    else sixteenthNoteDurationMs
                }
                isGroupedEighth && subdivision == SubdivisionMode.QUARTER -> {
                    val pattern = timeSignature.effectiveAccentPattern
                    if (pattern != null) eighthNoteDurationMs * pattern[clickIndex]
                    else eighthNoteDurationMs
                }
                subdivision == SubdivisionMode.EIGHTH -> {
                    if (isGroupedEighth) eighthNoteDurationMs
                    else quarterNoteDurationMs / 2.0
                }
                else -> quarterNoteDurationMs
            }

            // Write click
            track.write(clickSamples, 0, clickSamples.size)

            // Update UI
            withContext(Dispatchers.Main) {
                onPositionUpdate(-1, beatNumber, effectiveTempo)
            }

            // Write silence
            val silenceDurationMs = beatDurationMs - clickDurationMs
            if (silenceDurationMs > 0) {
                val silenceSamples = generateSilence(silenceDurationMs)
                track.write(silenceSamples, 0, silenceSamples.size)
            }
        }
    }

    /**
     * Stop playback
     */
    fun stop() {
        playbackJob?.cancel()
        playbackJob = null
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        _isPlaying.value = false
    }
}
