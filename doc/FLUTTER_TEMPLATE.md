This is a template for Flutter documents. You can get to it at flutter.dev/go/template.
After copying this template to create a new document (File > Make a copy), you should:
Update the {Document Title} heading above (double-click to edit).
Update the Google Docs document name (top left) to match. Make sure to leave "(PUBLICLY SHARED)" at the end of the title.
Replace {Author Name} with your name, and {GitHub ID} with your GitHub ID.
Replace {Month} and {Year} with today's month and year. As you update the document in the future, update the “Last Updated” date to match the date when you made the latest significant update.
Ensure your document is shared with everyone:
(Note: if you are a Google employee, make sure that this doc is owned by a non-Google account (don’t use your @google.com account), such as @gmail.com. Otherwise non-Googlers can’t see the doc unless they log in to Google.)
Click Share in the top right.
If your Google account is part of an organization:
Click Change Link To <organization> at the bottom left of the dialog that appears.
Click on the organization name in the dropdown and select “Anyone with the link”
If your Google account is not part of an organization:
Click “Change to anyone with the link” on the bottom left of the dialog that appears.
Change Viewer to Commenter in the dropdown near the bottom right corner.
Add docsowner@fcontrib.org as an editor for the document so that we can manage legacy documents.
Click Done.
If you are a Google employee, add a shortcut to the Design Docs folder using File > Add Shortcut to Drive.
Open an incognito window in your browser and see if you can open your document there. If not, check the sharing settings again!
Edit this document to your heart's content!
Do not change the headers and footers or the background color, and keep it in the “Print Layout” view to help make it clear that this is a publicly visible document.
Once the doc is ready to share (please do not file the PR until you’ve got some content to share!), go to https://github.com/flutter/website/blob/main/firebase.json and add an entry that redirects to your document, as follows:
Open that page on GitHub.
Click the pencil at the top right of that page (next to History).
Make a copy of an existing “go” link.
Add the new link in alphabetical order. Each line requires a comma, except the very last line, which should have no comma. (Either of these can break the website build.)
Update the link on your new line, and update the destination to point to this document.
Select Create a new branch for this commit and start a pull request.
Click Propose changes.
Convert the go link text in this document to an actual link to the proposed go link.
File an issue using the design doc issue template and assign it to yourself.
If you want to solicit feedback on your design doc, see suggestions for how to do this on our wiki.
Remember to delete these instructions by right clicking on them and selecting “Delete table” from the context menu!
The remainder of this template is a structure that we recommend using based on years of engineering experience. However, feel free to use as much or as little as you think is necessary for your purposes. Not every section applies to every design doc.


SUMMARY
Place a very short introduction to your discussion or design here.

Author: {Author Name} ({GitHub ID})
Go Link: flutter.dev/go/{document-title}
Created: {Month}/{Year}   /  Last updated: {Month}/{Year}
WHAT PROBLEM IS THIS SOLVING?
Objectives of the discussion or design.

Suggestion: If you’re proposing a user-facing change to Flutter, describe the problem this proposal addresses from the user’s point of view, including
Who are the intended users? Be as specific as possible, in terms of their roles, responsibilities, levels of expertise, and other attributes that might have an impact on how likely they’d find your solution useful and usable. 
What is the problem this solution can help the intended users solve?  

Here are some examples:
“Flutter application developers, especially those who’re not performance specialists, do not have a convenient way to detect memory leaks in their apps during debugging sessions, resulting in performance problems impacting app users.“
“Web developers, expecting standard web look & feel, are discouraged from building web apps using Flutter, because text in Flutter is not selectable by default.” 
“Flutter plugin authors often need to write complex and error-prone code, because many plugins have to deal with allocating, tracking, and deallocating native resources.”

BACKGROUND
Background needed to understand the problem domain. Don’t include any “solutions” in this section.
Audience
Consider who you are writing for. Be explicit about who your audience is. Anyone contributing to Flutter? Just people who are regular contributors to a particular source file? Only you and your tech lead? The background section should be sufficient for people in your audience to understand your proposal.
Glossary
Terms Relevant to Discussion - A minimal set of definitions of terms needed to understand the problem domain go here. Do not include widely known concepts (e.g. don’t define “URL” or “GUI”), just things needed to understand the discussion.
OVERVIEW
Overview of the design or discussion.
Non-goals
What is specifically not being addressed by this discussion or design.
USAGE EXAMPLES
How would the user experience the proposed solution? Provide a few examples illustrating how the user will use the proposed solution in realistic scenarios. If the proposal is an API, include sample code in accordance with Flutter’s style guide. Include brief inline explanations of key concepts this proposal introduces. If applicable, show before-and-after comparisons. Here is an example for your reference:
GoRouter API improvements (PUBLICLY SHARED)

If the proposal is a GUI or CLI, include a detailed description of each usage scenario. You’re also encouraged to include paper sketches, wireframes or storyboards as visual aid. It’s completely fine to keep them at a low fidelity (e.g., paper-based) to facilitate discussions. Here is an example for your reference:
[scenario description]Detect Memory Leaks (PUBLICLY SHARED)

You may integrate usage examples into the Detailed Design/Discussion section if doing so makes your doc flow better. However, mark them clearly with subsection headings, so a reader who doesn’t wish to review the implementation can still provide feedback on the intended usage of your proposed solution. 
DETAILED DESIGN/DISCUSSION
Detailed Design. Discuss.
ACCESSIBILITY
Explain how accessibility needs will be addressed by the proposal.
INTERNATIONALIZATION
Explain how internationalization and localization needs will be addressed by the proposal.
INTEGRATION WITH EXISTING FEATURES
Explain how existing features are affected by the proposal. How will you adjust existing APIs and features so that in the end, the combined API feels like it was always designed to have the proposed feature?
OPEN QUESTIONS
Will it work?
TESTING PLAN
Provide a description of testing or a link to a testing plan here, if the discussion involves something that can be tested.
DOCUMENTATION PLAN
Provide a description of the planned documentation and code samples that will be provided for the implementation, both for the API documentation and for any specialized articles for the website.
MIGRATION PLAN
Provide a description of the migration plan or a link to a migration plan here, if the discussion involves something that must be migrated.
