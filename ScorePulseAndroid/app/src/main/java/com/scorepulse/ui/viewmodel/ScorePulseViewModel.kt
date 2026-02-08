package com.scorepulse.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.scorepulse.audio.MetronomeEngine
import com.scorepulse.data.ScoreStorageManager
import com.scorepulse.model.Score
import com.scorepulse.model.SubdivisionMode
import com.scorepulse.model.TimeSignature
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for managing scores and app state
 */
class ScorePulseViewModel(application: Application) : AndroidViewModel(application) {
    
    private val storageManager = ScoreStorageManager(application)
    val metronomeEngine = MetronomeEngine()
    
    private val _bundledScores = MutableStateFlow<List<Score>>(emptyList())
    val bundledScores: StateFlow<List<Score>> = _bundledScores.asStateFlow()
    
    private val _userScores = MutableStateFlow<List<Score>>(emptyList())
    val userScores: StateFlow<List<Score>> = _userScores.asStateFlow()
    
    // Simple metronome state
    private val _bpm = MutableStateFlow(120)
    val bpm: StateFlow<Int> = _bpm.asStateFlow()
    
    private val _timeSignature = MutableStateFlow(TimeSignature.FOUR_FOUR)
    val timeSignature: StateFlow<TimeSignature> = _timeSignature.asStateFlow()
    
    private val _subdivision = MutableStateFlow(SubdivisionMode.QUARTER)
    val subdivision: StateFlow<SubdivisionMode> = _subdivision.asStateFlow()
    
    init {
        loadScores()
    }
    
    private fun loadScores() {
        viewModelScope.launch {
            _bundledScores.value = storageManager.loadBundledScores()
            _userScores.value = storageManager.loadUserScores()
        }
    }
    
    fun setBpm(value: Int) {
        _bpm.value = value.coerceIn(40, 240)
    }
    
    fun setTimeSignature(ts: TimeSignature) {
        _timeSignature.value = ts
    }
    
    fun setSubdivision(mode: SubdivisionMode) {
        _subdivision.value = mode
    }
    
    fun startMetronome() {
        metronomeEngine.startMetronome(
            bpm = _bpm.value,
            timeSignature = _timeSignature.value,
            subdivision = _subdivision.value
        )
    }
    
    fun stopMetronome() {
        metronomeEngine.stop()
    }
    
    fun importScore(jsonString: String): Result<Score> {
        return try {
            val score = storageManager.importScore(jsonString)
            _userScores.value = _userScores.value + score
            Result.success(score)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    fun deleteScore(score: Score) {
        storageManager.deleteScore(score)
        _userScores.value = _userScores.value.filter { it.id != score.id }
    }
    
    fun isBundledScore(score: Score): Boolean {
        return _bundledScores.value.any { it.id == score.id }
    }
    
    override fun onCleared() {
        super.onCleared()
        metronomeEngine.stop()
    }
}
