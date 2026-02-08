package com.scorepulse.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scorepulse.model.SubdivisionMode
import com.scorepulse.model.TimeSignature
import com.scorepulse.ui.viewmodel.ScorePulseViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MetronomeScreen(viewModel: ScorePulseViewModel) {
    val bpm by viewModel.bpm.collectAsState()
    val timeSignature by viewModel.timeSignature.collectAsState()
    val subdivision by viewModel.subdivision.collectAsState()
    val isPlaying by viewModel.metronomeEngine.isPlaying.collectAsState()
    val currentBeat by viewModel.metronomeEngine.currentBeat.collectAsState()

    val beatPulseColor by animateColorAsState(
        targetValue = if (isPlaying) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
        label = "beatPulse"
    )

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Metronome") })
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Beat indicator
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .clip(CircleShape)
                    .background(beatPulseColor),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "Beat",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Text(
                        text = "$currentBeat",
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                }
            }

            // Tempo display
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "♩ = $bpm",
                        fontSize = 40.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Slider(
                        value = bpm.toFloat(),
                        onValueChange = { viewModel.setBpm(it.toInt()) },
                        valueRange = 40f..240f,
                        steps = 199,
                        enabled = !isPlaying,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                }
            }

            // Time signature picker
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = timeSignature.displayString,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    TimeSignaturePicker(
                        selected = timeSignature,
                        onSelect = { viewModel.setTimeSignature(it) },
                        enabled = !isPlaying
                    )
                }
            }

            // Subdivision picker
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Subdivision",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    SubdivisionPicker(
                        selected = subdivision,
                        onSelect = { viewModel.setSubdivision(it) },
                        enabled = !isPlaying
                    )
                }
            }

            // Play/Stop button
            Button(
                onClick = {
                    if (isPlaying) {
                        viewModel.stopMetronome()
                    } else {
                        viewModel.startMetronome()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isPlaying) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
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
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimeSignaturePicker(
    selected: TimeSignature,
    onSelect: (TimeSignature) -> Unit,
    enabled: Boolean
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        TimeSignature.COMMON.take(5).forEach { ts ->
            FilterChip(
                selected = ts == selected,
                onClick = { onSelect(ts) },
                label = { Text(ts.displayString, fontSize = 12.sp) },
                enabled = enabled
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SubdivisionPicker(
    selected: SubdivisionMode,
    onSelect: (SubdivisionMode) -> Unit,
    enabled: Boolean
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        SubdivisionMode.entries.forEach { mode ->
            FilterChip(
                selected = mode == selected,
                onClick = { onSelect(mode) },
                label = { Text(mode.displaySymbol, fontSize = 20.sp) },
                enabled = enabled
            )
        }
    }
}
