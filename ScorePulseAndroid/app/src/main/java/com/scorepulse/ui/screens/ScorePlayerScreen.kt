package com.scorepulse.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.scorepulse.model.Score
import com.scorepulse.model.SubdivisionMode
import com.scorepulse.ui.viewmodel.ScorePlayerViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScorePlayerScreen(
    score: Score,
    onBack: () -> Unit,
    viewModel: ScorePlayerViewModel = viewModel()
) {
    val currentBar by viewModel.currentBar.collectAsState()
    val currentBeat by viewModel.currentBeat.collectAsState()
    val currentDisplayTempo by viewModel.currentDisplayTempo.collectAsState()
    val tempoMultiplier by viewModel.tempoMultiplier.collectAsState()
    val subdivision by viewModel.subdivision.collectAsState()
    val rehearsalMode by viewModel.rehearsalMode.collectAsState()
    val countIn by viewModel.countIn.collectAsState()
    val isCountingIn by viewModel.isCountingIn.collectAsState()
    val isPlaying by viewModel.metronomeEngine.isPlaying.collectAsState()

    var showGoToBarDialog by remember { mutableStateOf(false) }
    var goToBarInput by remember { mutableStateOf("") }

    val currentTimeSignature = score.timeSignature(currentBar)
    val currentTempo = score.tempo(currentBar)
    val effectiveTempo = currentDisplayTempo ?: (currentTempo * tempoMultiplier).toInt()
    val currentRehearsalMark = score.rehearsalMark(currentBar)

    val beatPulseColor by animateColorAsState(
        targetValue = when {
            !isPlaying -> MaterialTheme.colorScheme.surfaceVariant
            isCountingIn -> MaterialTheme.colorScheme.primary
            else -> MaterialTheme.colorScheme.secondary
        },
        label = "beatPulse"
    )

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { 
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(score.title, style = MaterialTheme.typography.titleMedium)
                        Text(score.composer, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = {
                        viewModel.stopPlayback()
                        onBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Beat indicator and position display
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(70.dp)
                            .clip(CircleShape)
                            .background(beatPulseColor),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = if (isCountingIn) "Count" else "Beat",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onPrimary
                            )
                            Text(
                                text = "$currentBeat",
                                fontSize = 28.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimary
                            )
                        }
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            currentRehearsalMark?.let { mark ->
                                Text(
                                    text = mark.displayText,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Text(
                                text = "Bar $currentBar / ${score.totalBars}",
                                style = MaterialTheme.typography.titleMedium
                            )
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(currentTimeSignature.displayString, style = MaterialTheme.typography.bodyMedium)
                            Text("♩=$effectiveTempo", style = MaterialTheme.typography.bodyMedium)
                        }
                        score.tempoMarking(currentBar)?.let {
                            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }

            // Tempo adjustment
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("${(tempoMultiplier * 100).toInt()}%", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.width(44.dp))
                    IconButton(onClick = { viewModel.adjustTempo(-0.05) }, enabled = !isPlaying, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Default.Remove, contentDescription = null)
                    }
                    Slider(
                        value = tempoMultiplier.toFloat(),
                        onValueChange = { viewModel.setTempoMultiplier(it.toDouble()) },
                        valueRange = 0.5f..1.5f,
                        enabled = !isPlaying,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = { viewModel.adjustTempo(0.05) }, enabled = !isPlaying, modifier = Modifier.size(36.dp)) {
                        Icon(Icons.Default.Add, contentDescription = null)
                    }
                    TextButton(onClick = { viewModel.setTempoMultiplier(1.0) }, enabled = tempoMultiplier != 1.0) {
                        Text("Reset")
                    }
                }
            }

            // Navigation controls
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextButton(
                            onClick = { viewModel.goToPreviousMark(score) },
                            enabled = score.previousRehearsalMark(currentBar) != null && !isPlaying
                        ) {
                            Icon(Icons.Default.ChevronLeft, contentDescription = null)
                            Text("Prev")
                        }
                        TextButton(onClick = { showGoToBarDialog = true }, enabled = !isPlaying) {
                            Text("Bar $currentBar", color = MaterialTheme.colorScheme.primary)
                        }
                        TextButton(
                            onClick = { viewModel.goToNextMark(score) },
                            enabled = score.nextRehearsalMark(currentBar) != null && !isPlaying
                        ) {
                            Text("Next")
                            Icon(Icons.Default.ChevronRight, contentDescription = null)
                        }
                    }
                    Slider(
                        value = currentBar.toFloat(),
                        onValueChange = { viewModel.setCurrentBar(it.toInt()) },
                        valueRange = 1f..score.totalBars.toFloat(),
                        enabled = !isPlaying
                    )
                }
            }

            // Options row: Loop, Count-in
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Card(modifier = Modifier.weight(1f)) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Loop", style = MaterialTheme.typography.bodyMedium)
                        Switch(
                            checked = rehearsalMode,
                            onCheckedChange = { viewModel.setRehearsalMode(it) },
                            enabled = !isPlaying
                        )
                    }
                }
                Card(modifier = Modifier.weight(1f)) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Count", style = MaterialTheme.typography.bodyMedium)
                        Switch(
                            checked = countIn,
                            onCheckedChange = { viewModel.setCountIn(it) },
                            enabled = !isPlaying
                        )
                    }
                }
            }

            // Subdivision
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Subdivision:", style = MaterialTheme.typography.bodyMedium)
                    Spacer(modifier = Modifier.width(12.dp))
                    SubdivisionMode.entries.forEach { mode ->
                        FilterChip(
                            selected = mode == subdivision,
                            onClick = { viewModel.setSubdivision(mode) },
                            label = { Text(mode.displaySymbol) },
                            enabled = !isPlaying,
                            modifier = Modifier.padding(end = 8.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Play/Stop button
            Button(
                onClick = {
                    if (isPlaying) viewModel.stopPlayback() else viewModel.startPlayback(score)
                },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isPlaying) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.secondary
                )
            ) {
                Icon(
                    imageVector = if (isPlaying) Icons.Default.Stop else Icons.Default.PlayArrow,
                    contentDescription = null
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(if (isPlaying) "Stop" else "Start")
            }
        }
    }

    if (showGoToBarDialog) {
        AlertDialog(
            onDismissRequest = { showGoToBarDialog = false; goToBarInput = "" },
            title = { Text("Go to Bar") },
            text = {
                OutlinedTextField(
                    value = goToBarInput,
                    onValueChange = { goToBarInput = it.filter { c -> c.isDigit() } },
                    label = { Text("Bar (1-${score.totalBars})") },
                    singleLine = true
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    goToBarInput.toIntOrNull()?.let { bar ->
                        if (bar in 1..score.totalBars) viewModel.setCurrentBar(bar)
                    }
                    showGoToBarDialog = false
                    goToBarInput = ""
                }) { Text("Go") }
            },
            dismissButton = {
                TextButton(onClick = { showGoToBarDialog = false; goToBarInput = "" }) { Text("Cancel") }
            }
        )
    }
}
