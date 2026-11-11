package com.elderguard.ai.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.alerts.AlertPayload

object SosScreenTags {
    const val SCREEN = "sosScreen"
    const val LIST = "sosList"
    const val CONFIRMATION = "sosConfirmation"
    const val CONTACTS = "sosContacts"
    const val LOCATION = "sosLocation"
    const val CANCEL = "sosCancel"
}

// The confirmation, when there is one, is the item centered on the screen at start.
private const val CONFIRMATION_ITEM = 1

/**
 * Full-screen red overlay shown while SOS is active, like the web app's SOS screen: "Pidiendo
 * ayuda…", the confirmation of the [alert] sent (who was notified, as a mock, and the GPS
 * coordinates), and a large cancel button. It covers and blocks the watchface underneath.
 *
 * The three parts do not fit a round watch at a readable size, so they are a ScalingLazyColumn
 * that opens centered on the confirmation, with the cancel button just below.
 */
@Composable
fun SosScreen(onCancel: () -> Unit, modifier: Modifier = Modifier, alert: AlertPayload? = null) {
    val listState = rememberScalingLazyListState(initialCenterItemIndex = if (alert == null) 0 else CONFIRMATION_ITEM)
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(WatchColors.Danger)
            // Takes every touch, so nothing behind the overlay can be pressed or scrolled.
            .pointerInput(Unit) {}
            .testTag(SosScreenTags.SCREEN),
    ) {
        ScalingLazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize().testTag(SosScreenTags.LIST),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                Text(
                    text = stringResource(R.string.sos_active),
                    color = WatchColors.OnDanger,
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.title2,
                    fontWeight = FontWeight.Bold,
                    // Screen readers announce it as soon as the screen appears.
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                )
            }
            if (alert != null) {
                item { AlertConfirmation(alert) }
            }
            item {
                Button(
                    onClick = onCancel,
                    modifier = Modifier.fillMaxWidth(0.8f).height(56.dp).testTag(SosScreenTags.CANCEL),
                    shape = RoundedCornerShape(28.dp),
                    // White on red: inverted from the screen, so the only action stands out.
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = WatchColors.OnDanger,
                        contentColor = WatchColors.Danger,
                    ),
                    border = ButtonDefaults.buttonBorder(borderStroke = BorderStroke(2.dp, WatchColors.OnDanger)),
                ) {
                    Text(
                        text = stringResource(R.string.sos_cancel),
                        style = MaterialTheme.typography.title2,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
        PositionIndicator(scalingLazyListState = listState)
    }
}

/** "Avisados (simulado)", one contact name per line, and where the alert says the person is. */
@Composable
private fun AlertConfirmation(alert: AlertPayload) {
    val names = alert.contacts.map { it.name }
    val announcement = stringResource(R.string.sos_notified_announce, names.joinToString(", "))
    Column(
        modifier = Modifier
            .testTag(SosScreenTags.CONFIRMATION)
            // Announced once it arrives, like the web app: the title was read before it existed.
            .semantics { liveRegion = LiveRegionMode.Polite },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            text = stringResource(R.string.sos_notified),
            color = WatchColors.OnDanger,
            style = MaterialTheme.typography.caption1,
            modifier = Modifier.semantics { contentDescription = announcement },
        )
        // One line per name, so a name never breaks in the middle.
        Text(
            text = names.joinToString("\n"),
            color = WatchColors.OnDanger,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.title3,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.testTag(SosScreenTags.CONTACTS),
        )
        Text(
            text = alertLocationText(alert.gps),
            color = WatchColors.OnDanger,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.caption1,
            modifier = Modifier.testTag(SosScreenTags.LOCATION),
        )
    }
}
