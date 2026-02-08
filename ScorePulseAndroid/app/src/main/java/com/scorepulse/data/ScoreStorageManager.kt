package com.scorepulse.data

import android.content.Context
import com.scorepulse.model.Score
import com.scorepulse.model.ScoreCollection
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Manages score storage and retrieval
 */
class ScoreStorageManager(private val context: Context) {
    
    private val json = Json { 
        ignoreUnknownKeys = true 
        isLenient = true
    }

    private val scoresDir: File
        get() = File(context.filesDir, "Scores").also { 
            if (!it.exists()) it.mkdirs() 
        }

    /**
     * Load bundled scores from assets
     */
    fun loadBundledScores(): List<Score> {
        return try {
            val jsonString = context.assets.open("bundled-scores.json").bufferedReader().use { it.readText() }
            val collection = json.decodeFromString<ScoreCollection>(jsonString)
            collection.scores
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    /**
     * Load all user-imported scores
     */
    fun loadUserScores(): List<Score> {
        return scoresDir.listFiles()
            ?.filter { it.extension == "scorepulse" }
            ?.mapNotNull { file ->
                try {
                    val jsonString = file.readText()
                    json.decodeFromString<Score>(jsonString)
                } catch (e: Exception) {
                    e.printStackTrace()
                    null
                }
            }
            ?: emptyList()
    }

    /**
     * Import a score from JSON string
     */
    fun importScore(jsonString: String): Score {
        val score = json.decodeFromString<Score>(jsonString)
        val file = File(scoresDir, "${score.id}.scorepulse")
        file.writeText(jsonString)
        return score
    }

    /**
     * Delete a user score
     */
    fun deleteScore(score: Score) {
        val file = File(scoresDir, "${score.id}.scorepulse")
        if (file.exists()) {
            file.delete()
        }
    }
}
