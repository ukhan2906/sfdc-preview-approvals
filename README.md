# Approval Preview and Submission for Salesforce

<a href="https://githubsfdeploy.herokuapp.com?owner=ukhan2906&repo=sfdc-preview-approvals&ref=main">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

This repository contains an implementation of an approval process preview and submission tool for Salesforce. It consists of an Apex controller (`ApprovalPreviewControllerLWC`) and a Lightning Web Component (LWC) that work together to:

- **Preview the Approval Process:** Retrieve the details of the approval process for a given record (including the list of approval steps).
- **Submit the Record for Approval:** Allow users to submit the record for approval with associated comments.
- **Handle Already Submitted Records:** If a record is already submitted for approval, display the existing approval steps (with their status) and disable further submissions.

## Table of Contents

- [Overview](#overview)
- [Functional Workflow](#functional-workflow)
- [Architecture](#architecture)
- [Installation & Setup](#installation--setup)
- [Usage](#usage)
- [Enhancements](#enhancements)
- [Future Enhancements](#future-enhancements)
- [Flow Diagram](#flow-diagram)
- [License](#license)

## Overview

This project allows Salesforce users to easily preview an approval process for a record and submit it for approval. When a record is already in the approval process, it displays a list of approved and pending steps. If a step name is missing (e.g., null), the code replaces it with "Started". The solution enhances user experience by preventing duplicate submissions and providing clear status feedback.

## Functional Workflow

1. **Record Identification:**  
   The Lightning Web Component (LWC) retrieves the current record's ID from the page state.

2. **Approval Process Preview:**  
   The LWC calls the `runPreview` method in the Apex controller.  
   - If the record meets the criteria for an approval process, the controller simulates the approval submission to generate preview data (approval process name, description, and steps).
   - If the record is already in the approval process, the controller queries existing process details and returns a list of steps (with their status). In such cases, the submit button is disabled.

3. **Submission for Approval:**  
   When the user confirms the submission, the LWC calls the `submitForApproval` method in the Apex controller, which submits the record for approval using the collected steps.

## Architecture

- **Apex Controller (ApprovalPreviewControllerLWC):**
  - Contains methods to simulate the approval process and to query existing approval details.
  - Provides a response object (`ApprovalPreviewResponse`) that includes the approval process details, steps, and a flag indicating if the record is already submitted.

- **Lightning Web Component (approvalPreview):**
  - Retrieves the record ID, calls the Apex methods to load approval data, and displays the process details in a user-friendly format.
  - Shows a spinner while data is loading.
  - Disables the "Submit for Approval" button if the record is already submitted.

## Installation & Setup

1. **Deploy Apex Code:**
   - Deploy the `ApprovalPreviewControllerLWC` class and the simulated helper classes (`ProcessInstance`, `ProcessInstanceHistory`) to your Salesforce org.
   - Ensure that the Apex class is enabled for Lightning Components via the `@AuraEnabled` annotation.

2. **Deploy Lightning Web Component:**
   - Add the `approvalPreview` component to your Salesforce Lightning page.
   - Configure the component to receive the record ID either via a Lightning record action or through the current page state.

3. **Testing:**
   - Open a record detail page (e.g., Account) and verify that the component loads the approval preview.
   - Test the submission functionality and observe that the submit button is disabled if the record is already submitted.

## Usage

- **Preview:**  
  When the component loads, it automatically calls the `runPreview` method to fetch the approval process details and display them in a table.

- **Submit for Approval:**  
  If the record is not already in the approval process, clicking the "Submit for Approval" button triggers the submission method. A confirmation prompt ensures that users understand the process cannot be recalled once submitted.

- **Go Back:**  
  The "Go Back" button returns the user to the record's detail page.

## Enhancements

- **Null Step Name Handling:**  
  If the first approval step is null, it is replaced with "Started" to ensure clarity.

- **Display Existing Process Details:**  
  If the record is already submitted for approval, the component queries and displays existing steps (approved and pending) with status information, preventing duplicate submissions.

- **Custom Labels and Constants:**  
  (Enhancement Suggestion) Use custom labels and constants for error messages and common texts to ease localization and maintenance.

- **Improved Exception Logging:**  
  (Enhancement Suggestion) Add more detailed logging to track approval submission issues.

## Future Enhancements

- **TBD:**

## Flow Diagram

Below is a flow diagram illustrating the overall workflow:

```mermaid
graph TD;
    A[User Opens Record Page] --> B[Record ID Retrieved from Page State];
    B --> C[Component calls runPreview Apex Method];
    C --> D{Approval Process Applicable?};
    D -- Yes --> E[Simulate Approval Submission];
    E --> F[Retrieve Approval Steps];
    F --> G[Display Approval Process & Steps];
    D -- No --> H{Record Already Submitted?};
    H -- Yes --> I[Query Existing Approval Details];
    I --> G;
    H -- No --> J[Display Appropriate Error Message];
    G --> K[Enable/Disable Submit Button];
    K --> L{User Clicks 'Submit for Approval'?};
    L -- Yes --> M[Call submitForApproval Apex Method];
    M --> N[Submit Record for Approval];
    N --> O[Redirect to Record Page];
    L -- No --> P[Await Further Action];
