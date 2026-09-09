package com.acme.taskflow.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector

enum class Destination(val title: String, val icon: ImageVector) {
    AllTasks("All Tasks", Icons.Default.Assignment),
    MyTasks("My Tasks", Icons.Default.Person),
    Inbox("Inbox", Icons.Default.Inbox),
    Messages("Messages", Icons.Default.Chat),
    Meetings("Meetings", Icons.Default.Event),
    Calls("Calls", Icons.Default.VideoCall),
    Productivity("Productivity", Icons.Default.Bolt),
    Team("Team", Icons.Default.Groups),
    Sessions("Security Sessions", Icons.Default.Security)
}

data class Workspace(val name: String, val slug: String, val tier: String, val owner: String)
