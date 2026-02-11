import Testing
@testable import FlokMCP

/// Test suite for FlokPrompts workflow templates.
/// Verifies that all prompts contain necessary instructions and tool references.
@Suite("FlokPrompts Workflow Templates")
struct PromptsTests {

    // MARK: - Triage Inbox Prompt Tests

    @Test("triageInbox contains categorization instructions")
    func triageInboxContainsCategorize() {
        #expect(FlokPrompts.triageInbox.lowercased().contains("categorize"))
    }

    @Test("triageInbox references list-mail tool")
    func triageInboxReferencesListMail() {
        #expect(FlokPrompts.triageInbox.contains("list-mail"))
    }

    @Test("triageInbox references read-mail tool")
    func triageInboxReferencesReadMail() {
        #expect(FlokPrompts.triageInbox.contains("read-mail"))
    }

    @Test("triageInbox is non-empty")
    func triageInboxIsNonEmpty() {
        #expect(!FlokPrompts.triageInbox.isEmpty)
    }

    @Test("triageInbox mentions filtering unread messages")
    func triageInboxMentionsUnreadFilter() {
        #expect(FlokPrompts.triageInbox.contains("isRead eq false") ||
                FlokPrompts.triageInbox.lowercased().contains("unread"))
    }

    // MARK: - Schedule Meeting Prompt Tests

    @Test("scheduleMeeting contains availability check instructions")
    func scheduleMeetingContainsCheckAvailability() {
        #expect(FlokPrompts.scheduleMeeting.contains("check-availability"))
    }

    @Test("scheduleMeeting references create-event tool")
    func scheduleMeetingReferencesCreateEvent() {
        #expect(FlokPrompts.scheduleMeeting.contains("create-event"))
    }

    @Test("scheduleMeeting mentions attendees")
    func scheduleMeetingMentionsAttendees() {
        #expect(FlokPrompts.scheduleMeeting.lowercased().contains("attendees"))
    }

    @Test("scheduleMeeting is non-empty")
    func scheduleMeetingIsNonEmpty() {
        #expect(!FlokPrompts.scheduleMeeting.isEmpty)
    }

    @Test("scheduleMeeting suggests multiple time options")
    func scheduleMeetingSuggestsMultipleTimes() {
        #expect(FlokPrompts.scheduleMeeting.contains("3 optimal times") ||
                FlokPrompts.scheduleMeeting.lowercased().contains("suggest"))
    }

    // MARK: - Draft and Review Prompt Tests

    @Test("draftAndReview references send-mail tool")
    func draftAndReviewReferencesSendMail() {
        #expect(FlokPrompts.draftAndReview.contains("send-mail"))
    }

    @Test("draftAndReview contains draft instructions")
    func draftAndReviewContainsDraft() {
        #expect(FlokPrompts.draftAndReview.lowercased().contains("draft"))
    }

    @Test("draftAndReview mentions approval workflow")
    func draftAndReviewMentionsApproval() {
        #expect(FlokPrompts.draftAndReview.lowercased().contains("approval") ||
                FlokPrompts.draftAndReview.lowercased().contains("review"))
    }

    @Test("draftAndReview is non-empty")
    func draftAndReviewIsNonEmpty() {
        #expect(!FlokPrompts.draftAndReview.isEmpty)
    }

    @Test("draftAndReview mentions tone guidance")
    func draftAndReviewMentionsTone() {
        #expect(FlokPrompts.draftAndReview.lowercased().contains("tone") ||
                FlokPrompts.draftAndReview.lowercased().contains("professional"))
    }

    // MARK: - Daily Briefing Prompt Tests

    @Test("dailyBriefing references list-events tool")
    func dailyBriefingReferencesListEvents() {
        #expect(FlokPrompts.dailyBriefing.contains("list-events"))
    }

    @Test("dailyBriefing references list-mail tool")
    func dailyBriefingReferencesListMail() {
        #expect(FlokPrompts.dailyBriefing.contains("list-mail"))
    }

    @Test("dailyBriefing mentions schedule")
    func dailyBriefingMentionsSchedule() {
        #expect(FlokPrompts.dailyBriefing.lowercased().contains("schedule") ||
                FlokPrompts.dailyBriefing.lowercased().contains("calendar"))
    }

    @Test("dailyBriefing is non-empty")
    func dailyBriefingIsNonEmpty() {
        #expect(!FlokPrompts.dailyBriefing.isEmpty)
    }

    @Test("dailyBriefing includes summary structure")
    func dailyBriefingIncludesSummary() {
        #expect(FlokPrompts.dailyBriefing.lowercased().contains("summarize") ||
                FlokPrompts.dailyBriefing.contains("Summarize"))
    }

    @Test("dailyBriefing mentions urgent items")
    func dailyBriefingMentionsUrgent() {
        #expect(FlokPrompts.dailyBriefing.lowercased().contains("urgent") ||
                FlokPrompts.dailyBriefing.lowercased().contains("flagged"))
    }

    // MARK: - Contact Lookup Prompt Tests

    @Test("contactLookup references list-contacts tool")
    func contactLookupReferencesListContacts() {
        #expect(FlokPrompts.contactLookup.contains("list-contacts"))
    }

    @Test("contactLookup contains search instructions")
    func contactLookupContainsSearch() {
        #expect(FlokPrompts.contactLookup.lowercased().contains("search"))
    }

    @Test("contactLookup is non-empty")
    func contactLookupIsNonEmpty() {
        #expect(!FlokPrompts.contactLookup.isEmpty)
    }

    @Test("contactLookup mentions displaying contact info")
    func contactLookupMentionsDisplay() {
        #expect(FlokPrompts.contactLookup.lowercased().contains("display") ||
                FlokPrompts.contactLookup.lowercased().contains("show"))
    }

    @Test("contactLookup offers send-mail option")
    func contactLookupOffersSendMail() {
        #expect(FlokPrompts.contactLookup.contains("send-mail"))
    }

    // MARK: - Cross-Prompt Validation Tests

    @Test("All prompts are non-empty strings")
    func allPromptsAreNonEmpty() {
        let allPrompts = [
            FlokPrompts.triageInbox,
            FlokPrompts.scheduleMeeting,
            FlokPrompts.draftAndReview,
            FlokPrompts.dailyBriefing,
            FlokPrompts.contactLookup
        ]

        for prompt in allPrompts {
            #expect(!prompt.isEmpty, "All prompts should be non-empty")
        }
    }

    @Test("All prompts contain actionable tool references")
    func allPromptsContainToolReferences() {
        // Define known tool names from Flok
        let toolKeywords = [
            "list-mail", "read-mail", "send-mail", "reply-mail", "move-mail",
            "list-events", "create-event", "update-event", "delete-event",
            "check-availability", "list-contacts", "search"
        ]

        let prompts = [
            ("triageInbox", FlokPrompts.triageInbox),
            ("scheduleMeeting", FlokPrompts.scheduleMeeting),
            ("draftAndReview", FlokPrompts.draftAndReview),
            ("dailyBriefing", FlokPrompts.dailyBriefing),
            ("contactLookup", FlokPrompts.contactLookup)
        ]

        for (name, prompt) in prompts {
            let hasToolReference = toolKeywords.contains { tool in
                prompt.contains(tool)
            }
            #expect(hasToolReference, "\(name) should reference at least one tool")
        }
    }

    @Test("All prompts have reasonable length (>50 characters)")
    func allPromptsHaveReasonableLength() {
        let prompts = [
            ("triageInbox", FlokPrompts.triageInbox),
            ("scheduleMeeting", FlokPrompts.scheduleMeeting),
            ("draftAndReview", FlokPrompts.draftAndReview),
            ("dailyBriefing", FlokPrompts.dailyBriefing),
            ("contactLookup", FlokPrompts.contactLookup)
        ]

        for (name, prompt) in prompts {
            #expect(prompt.count > 50, "\(name) should have substantial content (>50 chars)")
        }
    }

    @Test("No prompts contain placeholder text")
    func noPromptsContainPlaceholders() {
        let placeholders = ["TODO", "FIXME", "XXX", "TBD", "PLACEHOLDER"]
        let allPrompts = [
            FlokPrompts.triageInbox,
            FlokPrompts.scheduleMeeting,
            FlokPrompts.draftAndReview,
            FlokPrompts.dailyBriefing,
            FlokPrompts.contactLookup
        ]

        for prompt in allPrompts {
            for placeholder in placeholders {
                #expect(!prompt.contains(placeholder),
                       "Prompts should not contain placeholder text like \(placeholder)")
            }
        }
    }

    // MARK: - Prompt Structure Tests

    @Test("triageInbox follows numbered step structure")
    func triageInboxFollowsNumberedStructure() {
        #expect(FlokPrompts.triageInbox.contains("1."))
        #expect(FlokPrompts.triageInbox.contains("2."))
        #expect(FlokPrompts.triageInbox.contains("3."))
    }

    @Test("scheduleMeeting follows numbered step structure")
    func scheduleMeetingFollowsNumberedStructure() {
        #expect(FlokPrompts.scheduleMeeting.contains("1."))
        #expect(FlokPrompts.scheduleMeeting.contains("2."))
        #expect(FlokPrompts.scheduleMeeting.contains("3."))
    }

    @Test("draftAndReview follows numbered step structure")
    func draftAndReviewFollowsNumberedStructure() {
        #expect(FlokPrompts.draftAndReview.contains("1."))
        #expect(FlokPrompts.draftAndReview.contains("2."))
        #expect(FlokPrompts.draftAndReview.contains("3."))
        #expect(FlokPrompts.draftAndReview.contains("4."))
    }

    @Test("dailyBriefing follows numbered step structure")
    func dailyBriefingFollowsNumberedStructure() {
        #expect(FlokPrompts.dailyBriefing.contains("1."))
        #expect(FlokPrompts.dailyBriefing.contains("2."))
        #expect(FlokPrompts.dailyBriefing.contains("3."))
    }

    @Test("contactLookup follows numbered step structure")
    func contactLookupFollowsNumberedStructure() {
        #expect(FlokPrompts.contactLookup.contains("1."))
        #expect(FlokPrompts.contactLookup.contains("2."))
        #expect(FlokPrompts.contactLookup.contains("3."))
    }
}
