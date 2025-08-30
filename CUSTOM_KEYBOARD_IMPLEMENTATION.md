# Custom Keyboard Implementation for FluffyChat

This implementation adds Telegram-style custom keyboard support for FluffyChat, allowing bots to display interactive button keyboards below the message input.

## Features

1. **Bot Detection**: Automatically detects when chatting with a bot (usernames ending with "bot")
2. **Custom Keyboard Display**: Shows responsive button grids based on bot messages
3. **Toggle Button**: Allows users to show/hide the custom keyboard
4. **Start Button**: Automatically shows a start button for bots without keyboard data
5. **Message Integration**: Buttons send their callback data as text messages
6. **Responsive Design**: Keyboards adapt to different screen sizes and button arrangements

## How It Works

### 1. Bot Detection
- Checks if the current room is a direct message with a bot
- Bot detection is based on Matrix IDs ending with "bot" (e.g., `@reminderbot:example.com`)

### 2. Keyboard Data Structure
Bots can include keyboard data in their message content using this structure:

```json
{
  "msgtype": "m.text",
  "body": "چه کاری برایت انجام دهم؟",
  "keyboard": {
    "buttons": [
      [
        {
          "callback_data": "!remind help",
          "text": "📝 یادآور جدید"
        },
        {
          "callback_data": "!remind list", 
          "text": "📋 لیست یادآورها"
        }
      ],
      [
        {
          "callback_data": "!remind again",
          "text": "🔁 ویرایش زمان یادآور"
        }
      ]
    ],
    "input_field_placeholder": "دستور را انتخاب کنید یا تایپ کنید...",
    "is_persistent": true,
    "resize_keyboard": true
  }
}
```

### 3. User Interface Elements

- **Centered Start Button**: Large, prominent button that appears alone when first chatting with a bot (Telegram-style)
- **Hidden Composer**: Message input and other UI elements are hidden until bot interaction begins
- **Keyboard Toggle Button**: Shows/hides the custom keyboard (appears when keyboard data is available)
- **Custom Keyboard**: Displays below the message input with responsive button layout

## File Structure

### New Files
- `lib/widgets/custom_keyboard.dart` - The custom keyboard widget
- `lib/utils/bot_utils.dart` - Utility functions for bot detection and keyboard parsing
- `test/bot_keyboard_test.dart` - Unit tests for the bot utilities

### Modified Files
- `lib/pages/chat/chat.dart` - Added keyboard state management and bot interaction functions
- `lib/pages/chat/chat_view.dart` - Integrated custom keyboard into the chat interface
- `lib/pages/chat/chat_input_row.dart` - Added toggle and start buttons

## Key Functions

### BotUtils Class
- `isBotUser(String userId)` - Detects if a user is a bot
- `isDirectMessageWithBot(Room room)` - Checks if room is a DM with a bot
- `getLastBotMessageWithKeyboard(Room room, Timeline timeline)` - Gets the latest bot message with keyboard data
- `hasBotSentAnyMessages(Room room, Timeline timeline)` - Checks if bot has sent any messages (used for initial interface)
- `parseKeyboardButtons(Map<String, dynamic> keyboardData)` - Converts keyboard data to widget format
- `extractKeyboardData(Event event)` - Extracts keyboard from message content

### Chat Controller Additions
- `shouldShowCustomKeyboard` - Property to determine if keyboard toggle should be visible
- `shouldShowBotStartButton` - Property to determine if start button should be visible
- `shouldHideComposerForBot` - Property to determine if composer should be hidden for clean bot interface
- `botInteractionStarted` - Tracks whether the user has started interacting with the bot
- `toggleCustomKeyboard()` - Toggles keyboard visibility
- `startBotInteraction()` - Sends "!start" message to bot and shows normal interface
- `onCustomKeyboardButtonPressed(String callbackData)` - Handles button presses

## Usage Flow

1. **Initial Bot Contact**: When entering a DM with a bot that hasn't sent any messages, the interface shows only a centered "Start" button (like Telegram)
2. **Clean Interface**: The message composer, emoji picker, and all other UI elements are hidden initially
3. **Bot Activation**: Clicking start sends "!start" to the bot and reveals the normal chat interface
4. **Keyboard Display**: Bot responds with a message containing keyboard data
5. **Keyboard Toggle**: User can show/hide the keyboard using the toggle button
6. **Button Interaction**: Clicking keyboard buttons sends the callback data as messages
7. **Persistent Display**: Keyboard remains available until a new message updates it

## Responsive Design

The keyboard automatically adjusts to:
- Different numbers of buttons per row
- Varying button text lengths
- Different screen sizes
- RTL/LTR text directions

## Integration Notes

- The keyboard integrates seamlessly with existing emoji picker functionality
- Only one special input (keyboard or emoji picker) is shown at a time
- Keyboard state is managed alongside other chat UI states
- Full compatibility with existing FluffyChat features

## Testing

Run the included tests with:
```bash
flutter test test/bot_keyboard_test.dart
```

The tests cover:
- Bot user detection
- Keyboard data parsing
- Error handling for invalid data
- Property extraction from keyboard configuration 