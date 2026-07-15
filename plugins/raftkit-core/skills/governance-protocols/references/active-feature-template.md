# FEATURE SPECIFICATION: [Feature Name or Jira Ticket ID]

> **AI GOVERNANCE NOTE:** Claude Code subagents and CodeRabbit are strictly forbidden from writing or modifying code if this document is empty, incomplete, or missing architectural boundaries.

---

## 1. PRODUCT SUMMARY & SCOPE
*Provide a concise 2-3 sentence overview of what is being built and why.*
- **Objective:** 
- **Target Users:** 
- **Affected Subsystems:** [e.g., NextJS Frontend, Hono API Router, NeonDB Schema, SST/Lambda]

---

## 2. TECHNICAL SPECIFICATIONS & LAYERS

### A. Database Layer (NeonDB / Prisma / Drizzle)
*List all schema changes, new tables, or changes to existing queries. If no database changes are required, state "No DB Changes".*
- **New/Modified Tables:** 
- **Indexes Required:** 
- **Data Constraints:** [e.g., `user_id` must be foreign-keyed, unique constraints]

### B. Backend API Layer (Node / Hono Router)
*Define the exact path, inputs, and outputs for all new or modified API routes.*
- **Endpoint:** `POST /api/v1/resource` (example)
- **Request Body (JSON Schema / Zod):**
  ```typescript
  // Provide or describe the payload layout here
  ```
- **Expected Response (Success 200/201):**
  ```json
  { "success": true, "data": {} }
  ```
- **Error Handling Scenarios:** [e.g., Return 400 if validation fails, 404 if parent record is missing]

### C. Frontend Layer (NextJS / React / TypeScript / Tailwind)
*Define UI behavior, state management, and component architecture boundaries.*
- **Target Routes/Pages:** [e.g., `/dashboard/settings`]
- **Component Scope:** [e.g., Create a single Client Component `FeatureForm.tsx` inside `/components`]
- **State Boundaries:** [e.g., Local component state only, do not inject into global Redux/Zustand store]

---

## 3. CORE LOGIC & BUSINESS RULES
*Specify the explicit algorithmic or operational rules the AI must follow to avoid guessing.*
1. **Rule 1:** 
2. **Rule 2:** 
3. **Rule 3:** 

---

## 4. CRITICAL EDGE CASES & ERROR BOUNDARIES
*Directly target AI hallucinations by explicitly documenting where things usually go wrong.*
- **Validation Constraints:** [e.g., Reject string fields over 255 characters, prevent negative numeric inputs]
- **Asynchronous Operations:** [e.g., Ensure the SQS message is acknowledged only after the NeonDB transaction successfully commits]
- **Sentry/Logging Requirements:** [e.g., Explicitly catch database timeout errors and report them to Sentry with a `severity: error` tag]

---

## 5. ACCEPTANCE CRITERIA (PRE-FLIGHT GATE DEPLOYMENT)
*The automated gates and unit test behaviors that must pass before this feature can be pushed.*
- [ ] TypeScript compiles cleanly with zero type errors (`tsc --noEmit`).
- [ ] High-level test coverage added for the new Hono endpoint using Vitest/Jest.
- [ ] NextJS build passes production minification limits without layout shifting.
