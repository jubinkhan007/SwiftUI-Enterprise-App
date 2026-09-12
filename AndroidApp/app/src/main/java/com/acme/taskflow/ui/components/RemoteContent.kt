package com.acme.taskflow.ui.components

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

class RemoteState {
    var data by mutableStateOf<JsonElement>(JsonNull.INSTANCE)
    var loading by mutableStateOf(true)
    var error by mutableStateOf<String?>(null)
    var revision by mutableIntStateOf(0)
    fun refresh() { revision++ }
}

@Composable
fun rememberRemote(api: ApiClient, path: String, revision: Int = 0, query: Map<String, String> = emptyMap(), paged: Boolean = false): RemoteState {
    val state = remember(api, path, query) { RemoteState() }
    LaunchedEffect(state, state.revision, revision) {
        state.loading = true
        state.error = null
        try {
            state.data = if (paged) com.google.gson.Gson().toJsonTree(api.all(path, query)) else api.request(path, query = query).data
        } catch (e: CancellationException) { throw e
        } catch (e: Exception) { state.error = e.message ?: "Unable to load data."
        } finally { state.loading = false }
    }
    return state
}

@Composable
fun RemoteStatus(state: RemoteState) {
    if (state.loading) LinearProgressIndicator(Modifier.fillMaxWidth())
    state.error?.let { message ->
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Text(message, color = MaterialTheme.colorScheme.error)
            TextButton(onClick = state::refresh) { Text("Retry") }
        }
    }
}

class ActionState(private val scope: CoroutineScope) {
    var busy by mutableStateOf(false)
    var error by mutableStateOf<String?>(null)
    fun run(action: suspend () -> Unit) {
        if (busy) return
        busy = true
        error = null
        scope.launch {
            try { action()
            } catch (e: CancellationException) { throw e
            } catch (e: Exception) { error = e.message ?: "Unable to save changes."
            } finally { busy = false }
        }
    }
}

@Composable
fun rememberAction(): ActionState {
    val scope = rememberCoroutineScope()
    return remember(scope) { ActionState(scope) }
}

@Composable
fun ActionStatus(action: ActionState) {
    if (action.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
    action.error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(12.dp)) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToolButton(icon: ImageVector, label: String, enabled: Boolean = true, onClick: () -> Unit) {
    TooltipBox(positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
        tooltip = { PlainTooltip { Text(label) } }, state = rememberTooltipState()) {
        IconButton(onClick = onClick, enabled = enabled) { Icon(icon, contentDescription = label) }
    }
}

data class Choice(val value: String, val label: String)
fun choices(vararg values: String): List<Choice> = values.map { Choice(it, label(it)) }
fun label(value: String): String = value.split('_').joinToString(" ") { it.replaceFirstChar(Char::uppercase) }
fun dateLabel(value: String): String = runCatching {
    DateTimeFormatter.ofPattern("MMM d, yyyy HH:mm").withZone(ZoneId.systemDefault()).format(Instant.parse(value))
}.getOrDefault(value)

data class FormField(val key: String, val label: String, val initial: String = "", val required: Boolean = false,
    val options: List<Choice>? = null, val multiline: Boolean = false, val date: Boolean = false, val numeric: Boolean = false,
    val emitEmpty: Boolean = false)

@Composable
fun ChoiceMenu(label: String, value: String, options: List<Choice>, onChange: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text("$label: ${options.find { it.value == value }?.label ?: "Choose"}", modifier = Modifier.weight(1f))
            Icon(Icons.Default.ArrowDropDown, null)
        }
        DropdownMenu(expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option -> DropdownMenuItem(text = { Text(option.label) }, onClick = { onChange(option.value); expanded = false }) }
        }
    }
}

@Composable
fun EditorDialog(title: String, fields: List<FormField>, onDismiss: () -> Unit, onSubmit: suspend (JsonObject) -> Unit) {
    val values = remember { mutableStateMapOf<String, String>().apply { fields.forEach { put(it.key, it.initial) } } }
    val action = rememberAction()
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = { if (!action.busy) onDismiss() },
        title = { Text(title) },
        text = {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                fields.forEach { field ->
                    val value = values[field.key].orEmpty()
                    when {
                        field.options != null -> ChoiceMenu(field.label, value, field.options) { values[field.key] = it }
                        field.date -> OutlinedButton(onClick = {
                            val initial = runCatching { Instant.parse(value).atZone(ZoneId.systemDefault()) }.getOrDefault(ZonedDateTime.now().plusHours(1))
                            DatePickerDialog(context, { _, year, month, day ->
                                TimePickerDialog(context, { _, hour, minute ->
                                    values[field.key] = ZonedDateTime.of(year, month + 1, day, hour, minute, 0, 0, ZoneId.systemDefault()).toInstant().toString()
                                }, initial.hour, initial.minute, true).show()
                            }, initial.year, initial.monthValue - 1, initial.dayOfMonth).show()
                        }, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Event, null); Text("${field.label}: ${dateLabel(value).ifBlank { "Choose" }}") }
                        else -> OutlinedTextField(value, { values[field.key] = it }, label = { Text(field.label) },
                            modifier = Modifier.fillMaxWidth(), singleLine = !field.multiline,
                            minLines = if (field.multiline) 3 else 1,
                            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType =
                                if (field.numeric) androidx.compose.ui.text.input.KeyboardType.Number else androidx.compose.ui.text.input.KeyboardType.Text))
                    }
                }
                ActionStatus(action)
            }
        },
        confirmButton = {
            TextButton(enabled = !action.busy && fields.all { !it.required || !values[it.key].isNullOrBlank() }, onClick = {
                action.run {
                    val payload = JsonObject()
                    fields.forEach { field ->
                        val value = values[field.key].orEmpty().trim()
                        if (field.required || field.emitEmpty || value.isNotBlank()) {
                            if (field.numeric) payload.addProperty(field.key, value.toIntOrNull() ?: error("${field.label} must be a whole number."))
                            else if (field.date && value.isNotBlank()) payload.addProperty(field.key, Instant.parse(value).truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString())
                            else payload.addProperty(field.key, value)
                        }
                    }
                    onSubmit(payload)
                    onDismiss()
                }
            }) { Text("Save") }
        },
        dismissButton = { TextButton(enabled = !action.busy, onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
fun ConfirmDialog(title: String, message: String, onDismiss: () -> Unit, onConfirm: suspend () -> Unit) {
    val action = rememberAction()
    AlertDialog(onDismissRequest = { if (!action.busy) onDismiss() }, title = { Text(title) },
        text = { Column { Text(message); ActionStatus(action) } },
        confirmButton = { TextButton(enabled = !action.busy, onClick = { action.run { onConfirm(); onDismiss() } }) { Text("Confirm") } },
        dismissButton = { TextButton(enabled = !action.busy, onClick = onDismiss) { Text("Cancel") } })
}
