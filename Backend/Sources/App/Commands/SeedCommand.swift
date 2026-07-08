import Vapor
import Fluent
import SharedModels

/// A command to clear custom mock data and seed a comprehensive demo dataset.
public struct SeedCommand: AsyncCommand {
    public struct Signature: CommandSignature {
        public init() {}
    }

    public var help: String {
        "Seeds the database with test data for prototyping and demo."
    }

    public func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application
        let db = app.db
        let logger = app.logger
        
        logger.info("Seeding Database...")
        
        // 1. Clean existing mock data
        let seedEmails = ["ops@acme.com", "alice@acme.com", "bob@acme.com", "charlie@acme.com", "dave@acme.com"]
        for email in seedEmails {
            if let user = try await UserModel.query(on: db).filter(\.$email == email).first() {
                try await OrganizationMemberModel.query(on: db).filter(\.$user.$id == user.id!).delete()
                try await TimeLogModel.query(on: db).filter(\.$user.$id == user.id!).delete()
                try await TaskItemModel.query(on: db).filter(\.$assignee.$id == user.id!).delete()
                try await user.delete(on: db)
            }
        }
        
        if let org = try await OrganizationModel.query(on: db).filter(\.$slug == "acme").first() {
            try await AuditLogModel.query(on: db).filter(\.$organization.$id == org.id!).delete()
            try await TimeLogModel.query(on: db).filter(\.$organization.$id == org.id!).delete()
            try await TaskItemModel.query(on: db).filter(\.$organization.$id == org.id!).delete()
            try await SpaceModel.query(on: db).filter(\.$organization.$id == org.id!).delete()
            try await org.delete(on: db)
        }
        
        // 2. Create Users
        let hashedPw = try Bcrypt.hash("Password123!", cost: 4)
        
        let superAdmin = UserModel(
            email: "ops@acme.com",
            displayName: "Ops Admin",
            passwordHash: hashedPw,
            role: .admin,
            isSuperAdmin: true
        )
        try await superAdmin.save(on: db)
        
        let ownerUser = UserModel(
            email: "alice@acme.com",
            displayName: "Alice Chief",
            passwordHash: hashedPw,
            role: .member
        )
        try await ownerUser.save(on: db)
        
        let managerUser = UserModel(
            email: "bob@acme.com",
            displayName: "Bob Manager",
            passwordHash: hashedPw,
            role: .member
        )
        try await managerUser.save(on: db)
        
        let member1 = UserModel(
            email: "charlie@acme.com",
            displayName: "Charlie Dev",
            passwordHash: hashedPw,
            role: .member
        )
        try await member1.save(on: db)
        
        let member2 = UserModel(
            email: "dave@acme.com",
            displayName: "Dave Designer",
            passwordHash: hashedPw,
            role: .member
        )
        try await member2.save(on: db)
        
        logger.info("Users seeded successfully.")
        
        // 3. Create Organization
        let org = OrganizationModel(
            name: "Acme Corp",
            slug: "acme",
            description: "Default Pro Tier development workspace for TaskFlow Suite.",
            ownerId: ownerUser.id!,
            subscriptionTier: "pro",
            stripeCustomerId: "cus_mock_acme",
            stripeSubscriptionId: "sub_mock_acme",
            subscriptionStatus: "active",
            logoUrl: "https://tailwindui.com/plus/img/logos/workflow-mark-indigo-500.svg",
            brandColorHex: "#4f46e5"
        )
        try await org.save(on: db)
        
        // Add organization members
        let mem1 = OrganizationMemberModel(orgId: org.id!, userId: ownerUser.id!, role: .owner)
        let mem2 = OrganizationMemberModel(orgId: org.id!, userId: managerUser.id!, role: .manager)
        let mem3 = OrganizationMemberModel(orgId: org.id!, userId: member1.id!, role: .member)
        let mem4 = OrganizationMemberModel(orgId: org.id!, userId: member2.id!, role: .member)
        
        try await mem1.save(on: db)
        try await mem2.save(on: db)
        try await mem3.save(on: db)
        try await mem4.save(on: db)
        
        logger.info("Organization & memberships seeded successfully.")
        
        // 4. Create Workspace Spaces & Projects
        let space = SpaceModel(orgId: org.id!, name: "Engineering", description: "All engineering tasks and boards.")
        try await space.save(on: db)
        
        let project = ProjectModel(
            spaceId: space.id!,
            name: "TaskFlow Suite Development",
            description: "Sprint tracks for the mobile app and enterprise SaaS console.",
            issueKeyPrefix: "TF"
        )
        try await project.save(on: db)
        
        // Create standard workflow status lists
        let listBacklog = TaskListModel(projectId: project.id!, name: "Backlog", position: 1.0)
        let listInProgress = TaskListModel(projectId: project.id!, name: "In Progress", position: 2.0)
        let listDone = TaskListModel(projectId: project.id!, name: "Done", position: 3.0)
        
        try await listBacklog.save(on: db)
        try await listInProgress.save(on: db)
        try await listDone.save(on: db)
        
        // 5. Create Task Items
        let task1 = TaskItemModel(
            orgId: org.id!,
            listId: listInProgress.id!,
            projectId: project.id!,
            title: "Design dark mode iOS Kanban board layout",
            description: "Implement native card reordering and custom column headers for the dashboard board view.",
            status: .inProgress,
            priority: .high,
            taskType: .task,
            storyPoints: 5,
            issueKey: "TF-1",
            labels: ["ui", "ios", "frontend"],
            startDate: Date().addingTimeInterval(-86400 * 2),
            dueDate: Date().addingTimeInterval(86400 * 4),
            assigneeId: member2.id!
        )
        try await task1.save(on: db)
        
        let task2 = TaskItemModel(
            orgId: org.id!,
            listId: listBacklog.id!,
            projectId: project.id!,
            title: "Setup SAML 2.0 Identity Provider authentication",
            description: "Integrate certificate loading and ACS response XML parsing on the backend server.",
            status: .todo,
            priority: .medium,
            taskType: .task,
            storyPoints: 8,
            issueKey: "TF-2",
            labels: ["auth", "security", "backend"],
            startDate: Date(),
            dueDate: Date().addingTimeInterval(86400 * 10),
            assigneeId: member1.id!
        )
        try await task2.save(on: db)
        
        let task3 = TaskItemModel(
            orgId: org.id!,
            listId: listDone.id!,
            projectId: project.id!,
            title: "Integrate Stripe billing sandbox redirect portal",
            description: "Build checkout gateway hooks and local fallback mocks for trial verification.",
            status: .done,
            priority: .high,
            taskType: .task,
            storyPoints: 3,
            issueKey: "TF-3",
            labels: ["billing", "saas", "backend"],
            startDate: Date().addingTimeInterval(-86400 * 5),
            dueDate: Date().addingTimeInterval(-86400 * 1),
            assigneeId: member1.id!
        )
        try await task3.save(on: db)
        
        logger.info("Tasks seeded successfully.")
        
        // 6. Log Hours worked
        let log1 = TimeLogModel(
            taskId: task1.id!,
            userId: member2.id!,
            orgId: org.id!,
            hoursLogged: 4.5,
            loggedAt: Date(),
            description: "Created basic board column layout designs."
        )
        try await log1.save(on: db)
        
        let log2 = TimeLogModel(
            taskId: task3.id!,
            userId: member1.id!,
            orgId: org.id!,
            hoursLogged: 6.0,
            loggedAt: Date(),
            description: "Wired Vapor routes and added the mock tier updater."
        )
        try await log2.save(on: db)
        
        logger.info("Time logs seeded successfully.")
        
        // 7. Audit Log entries
        try await AuditLogModel.log(
            on: db,
            orgId: org.id!,
            userId: superAdmin.id!,
            userEmail: "ops@acme.com",
            action: "user.login",
            resourceType: "user",
            resourceId: superAdmin.id!,
            details: "Super-admin ops@acme.com logged into system dashboard from IP 127.0.0.1"
        )
        
        try await AuditLogModel.log(
            on: db,
            orgId: org.id!,
            userId: ownerUser.id!,
            userEmail: "alice@acme.com",
            action: "organization.upgrade",
            resourceType: "org",
            resourceId: org.id!,
            details: "Organization Acme Corp upgraded to Pro subscription plan"
        )
        
        try await AuditLogModel.log(
            on: db,
            orgId: org.id!,
            userId: ownerUser.id!,
            userEmail: "alice@acme.com",
            action: "member.invite",
            resourceType: "member",
            resourceId: managerUser.id!,
            details: "Bob Manager invited to workspace as Manager"
        )
        
        logger.info("Audit logs seeded successfully.")
        logger.info("Database seeding completed successfully! Ready for demo.")
    }
}
