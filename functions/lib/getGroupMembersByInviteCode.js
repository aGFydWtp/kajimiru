"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getGroupMembersByInviteCode = void 0;
const functions = __importStar(require("firebase-functions/v2"));
const admin = __importStar(require("firebase-admin"));
/**
 * Get group members by invite code
 * Returns members categorized by connection status (firebaseUid presence)
 */
exports.getGroupMembersByInviteCode = functions.https.onCall(async (request) => {
    // Verify authentication
    if (!request.auth) {
        throw new functions.https.HttpsError("unauthenticated", "認証が必要です");
    }
    const data = request.data;
    const { code } = data;
    if (!code || typeof code !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "招待コードが必要です");
    }
    try {
        const db = admin.firestore();
        // Find invite by code
        const invitesSnapshot = await db
            .collection("groupInvites")
            .where("code", "==", code)
            .limit(1)
            .get();
        if (invitesSnapshot.empty) {
            throw new functions.https.HttpsError("not-found", "招待コードが見つかりません");
        }
        const inviteDoc = invitesSnapshot.docs[0];
        const invite = inviteDoc.data();
        const groupId = invite.groupId;
        // Check if invite is valid
        if (!invite.isActive) {
            throw new functions.https.HttpsError("failed-precondition", "この招待コードは無効です");
        }
        // Check expiration
        if (invite.expiresAt && invite.expiresAt.toDate() < new Date()) {
            throw new functions.https.HttpsError("failed-precondition", "この招待コードは期限切れです");
        }
        // Get all members from the group
        const membersSnapshot = await db
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .where("deletedAt", "==", null)
            .get();
        const userConnectedMembers = [];
        const nonConnectedMembers = [];
        membersSnapshot.forEach((doc) => {
            const member = doc.data();
            const memberInfo = {
                id: doc.id,
                name: member.displayName || "名前なし",
            };
            if (member.userId) {
                userConnectedMembers.push(memberInfo);
            }
            else {
                nonConnectedMembers.push(memberInfo);
            }
        });
        return {
            userConnectedMembers,
            nonConnectedMembers,
        };
    }
    catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "メンバー情報の取得に失敗しました");
    }
});
//# sourceMappingURL=getGroupMembersByInviteCode.js.map