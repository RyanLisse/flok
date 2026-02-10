import Foundation

// MARK: - MCP Prompts (Composable Workflow Templates)

/// Pre-built prompt templates for common agent workflows.
/// Agents compose these to build complex workflows without new code.
public enum FlokPrompts {

    /// Triage inbox: categorize and prioritize unread messages.
    public static let triageInbox = """
    Review unread messages in the inbox. For each message:
    1. Categorize: urgent / needs-reply / informational / spam
    2. Summarize in one sentence
    3. Suggest action: reply, archive, flag, or delete

    Use list-mail with filter "isRead eq false" first, then read-mail for important ones.
    """

    /// Schedule a meeting: find availability and create event.
    public static let scheduleMeeting = """
    Schedule a meeting:
    1. Use check-availability to find free slots for all attendees
    2. Suggest 3 optimal times based on availability
    3. After user picks a time, use create-event with all attendees

    Ask for: attendees (emails), duration, preferred date range, subject.
    """

    /// Draft and review: compose an email with review step.
    public static let draftAndReview = """
    Help compose an email:
    1. Ask for recipient, subject, and key points
    2. Draft the email body
    3. Show draft for review
    4. After approval, use send-mail to send

    Use a professional but friendly tone unless instructed otherwise.
    """

    /// Daily briefing: summarize today's schedule and urgent mail.
    public static let dailyBriefing = """
    Create a daily briefing:
    1. Use list-events for today's calendar (calendarView)
    2. Use list-mail for unread/flagged messages
    3. Summarize:
       - 📅 Today's schedule (times + subjects)
       - 📬 Urgent/flagged emails needing attention
       - 📊 Quick stats (meetings count, unread count)
    """

    /// Contact lookup: find and display contact info.
    public static let contactLookup = """
    Find contact information:
    1. Use list-contacts with search to find the person
    2. Display: name, email, phone, company, title
    3. Offer to send-mail to them
    """
}
