package com.scorepulse

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.scorepulse.ui.screens.MetronomeScreen
import com.scorepulse.ui.screens.ScoreListScreen
import com.scorepulse.ui.screens.ScorePlayerScreen
import com.scorepulse.ui.theme.ScorePulseTheme
import com.scorepulse.ui.viewmodel.ScorePulseViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: ScorePulseViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle incoming file intent
        handleIntent(intent)
        
        setContent {
            ScorePulseTheme {
                ScorePulseApp(viewModel)
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            intent.data?.let { uri ->
                try {
                    val inputStream = contentResolver.openInputStream(uri)
                    val jsonString = inputStream?.bufferedReader()?.use { it.readText() }
                    inputStream?.close()
                    
                    if (jsonString != null) {
                        val result = viewModel.importScore(jsonString)
                        result.onSuccess { score ->
                            Toast.makeText(this, "Imported: ${score.title}", Toast.LENGTH_SHORT).show()
                        }.onFailure { e ->
                            Toast.makeText(this, "Import failed: ${e.message}", Toast.LENGTH_LONG).show()
                        }
                    }
                } catch (e: Exception) {
                    Toast.makeText(this, "Failed to open file: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}

sealed class Screen(val route: String, val title: String) {
    data object Metronome : Screen("metronome", "Metronome")
    data object Scores : Screen("scores", "Scores")
    data object Player : Screen("player/{scoreId}", "Player") {
        fun createRoute(scoreId: String) = "player/$scoreId"
    }
}

@Composable
fun ScorePulseApp(viewModel: ScorePulseViewModel) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bundledScores by viewModel.bundledScores.collectAsState()
    val userScores by viewModel.userScores.collectAsState()
    val allScores = bundledScores + userScores

    val bottomNavItems = listOf(Screen.Metronome, Screen.Scores)
    val showBottomNav = currentRoute in bottomNavItems.map { it.route }

    Scaffold(
        bottomBar = {
            if (showBottomNav) {
                NavigationBar {
                    bottomNavItems.forEach { screen ->
                        NavigationBarItem(
                            icon = {
                                Icon(
                                    imageVector = when (screen) {
                                        Screen.Metronome -> Icons.Default.MusicNote
                                        Screen.Scores -> Icons.Default.LibraryMusic
                                        else -> Icons.Default.MusicNote
                                    },
                                    contentDescription = screen.title
                                )
                            },
                            label = { Text(screen.title) },
                            selected = currentRoute == screen.route,
                            onClick = {
                                if (currentRoute != screen.route) {
                                    navController.navigate(screen.route) {
                                        popUpTo(Screen.Metronome.route) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Metronome.route,
            modifier = Modifier.padding(padding)
        ) {
            composable(Screen.Metronome.route) {
                MetronomeScreen(viewModel)
            }

            composable(Screen.Scores.route) {
                ScoreListScreen(
                    viewModel = viewModel,
                    onScoreClick = { score ->
                        navController.navigate(Screen.Player.createRoute(score.id.toString()))
                    }
                )
            }

            composable(
                route = Screen.Player.route,
                arguments = listOf(navArgument("scoreId") { type = NavType.StringType })
            ) { backStackEntry ->
                val scoreId = backStackEntry.arguments?.getString("scoreId")
                val score = allScores.find { it.id.toString() == scoreId }
                
                if (score != null) {
                    ScorePlayerScreen(
                        score = score,
                        onBack = { navController.popBackStack() }
                    )
                }
            }
        }
    }
}
