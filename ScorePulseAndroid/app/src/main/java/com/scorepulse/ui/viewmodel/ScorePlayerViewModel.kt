package com.scorepulse.ui.viewmodel

import androidx.lifecycle.ViewModel
import com.scorepulse.audio.MetronomeEngine
import com.scorepulse.model.Score
import com.scorepulse.model.SubdivisionMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * ViewModel for score player screen
 */
class ScorePlayerViewModel : ViewModel() {
    
    val metronomeEngine = MetronomeEngine()
    
    private val _currentBar = MutableStateFlow(1)
    val currentBar: StateFlow<Int> = _currentBar.asStateFlow()
    
    private val _currentBeat = MutableStateFlow(1)
    val currentBeat: StateFlow<Int> = _currentBeat.asStateFlow()
    
    private val _currentDisplayTempo = MutableStateFlow<Int?>(null)
    val currentDisplayTempo: StateFlow<Int?> = _currentDisplayTempo.asStateFlow()
    
    private val _tempoMultiplier = MutableStateFlow(1.0)
    val tempoMultiplier: StateFlow<Double> = _tempoMultiplier.asStateFlow()
    
    private val _subdivision = MutableStateFlow(SubdivisionMode.QUARTER)
    val subdivision: StateFlow<SubdivisionMode> = _subdivision.asStateFlow()
    
    private val _rehearsalMode = MutableStateFlow(false)
    val rehearsalMode: StateFlow<Boolean> = _rehearsalMode.asStateFlow()
    
    private val _countIn = MutableStateFlow(true)
    val countIn: StateFlow<Boolean> = _countIn.asStateFlow()
    
    private val _isCountingIn = MutableStateFlow(false)
    val isCountingIn: StateFlow<Boolean> = _isCountingIn.asStateFlow()
    
    private var playStartBar = 1
    
    fun setCurrentBar(bar: Int) {
        _currentBar.value = bar
    }
    
    fun setTempoMultiplier(value: Double) {
        _tempoMultiplier.value = value.coerceIn(0.5, 1.5)
    }
    
    fun adjustTempo(amount: Double) {
        setTempoMultiplier(_tempoMultiplier.value + amount)
    }
    
    fun setSubdivision(mode: SubdivisionMode) {
        _subdivision.value = mode
    }
    
    fun setRehearsalMode(enabled: Boolean) {
        _rehearsalMode.value = enabled
    }
    
    fun setCountIn(enabled: Boolean) {
        _countIn.value = enabled
    }
    
    fun startPlayback(score: Score) {
        playStartBar = _currentBar.value
        
        metronomeEngine.startScorePlayback(
            score = score,
            startBar = _currentBar.value,
            tempoMultiplier = _tempoMultiplier.value,
            subdivision = _subdivision.value,
            countIn = _countIn.value
        ) { bar, beat, tempo ->
            _isCountingIn.value = bar < 0
            if (bar >= 0) {
                _currentBar.value = bar
            }
            _currentBeat.value = beat
            _currentDisplayTempo.value = tempo
        }
    }
    
    fun stopPlayback() {
        metronomeEngine.stop()
        _currentDisplayTempo.value = null
        _isCountingIn.value = false
        
        if (_rehearsalMode.value) {
            _currentBar.value = playStartBar
        }
    }
    
    fun goToPreviousMark(score: Score) {
        score.previousRehearsalMark(_currentBar.value)?.let {
            _currentBar.value = it.bar
        }
    }
    
    fun goToNextMark(score: Score) {
        score.nextRehearsalMark(_currentBar.value)?.let {
            _currentBar.value = it.bar
        }
    }
    
    override fun onCleared() {
        super.onCleared()
        metronomeEngine.stop()
    }
}
