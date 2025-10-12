import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

interface GetMembersRequest {
  code: string;
}

interface MemberInfo {
  id: string;
  name: string;
}

interface GetMembersResponse {
  userConnectedMembers: MemberInfo[];
  nonConnectedMembers: MemberInfo[];
}

/**
 * Get group members by invite code
 * Returns members categorized by connection status (firebaseUid presence)
 */
export const getGroupMembersByInviteCode = functions.https.onCall(
  async (request): Promise<GetMembersResponse> => {
    // Verify authentication
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "認証が必要です"
      );
    }

    const data = request.data as GetMembersRequest;
    const {code} = data;

    if (!code || typeof code !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "招待コードが必要です"
      );
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
        throw new functions.https.HttpsError(
          "not-found",
          "招待コードが見つかりません"
        );
      }

      const inviteDoc = invitesSnapshot.docs[0];
      const invite = inviteDoc.data();
      const groupId = invite.groupId;

      // Check if invite is valid
      if (!invite.isActive) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "この招待コードは無効です"
        );
      }

      // Check expiration
      if (invite.expiresAt && invite.expiresAt.toDate() < new Date()) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "この招待コードは期限切れです"
        );
      }

      // Get all members from the group
      const membersSnapshot = await db
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .where("deletedAt", "==", null)
        .get();

      const userConnectedMembers: MemberInfo[] = [];
      const nonConnectedMembers: MemberInfo[] = [];

      membersSnapshot.forEach((doc) => {
        const member = doc.data();
        const memberInfo: MemberInfo = {
          id: doc.id,
          name: member.displayName || "名前なし",
        };

        if (member.userId) {
          userConnectedMembers.push(memberInfo);
        } else {
          nonConnectedMembers.push(memberInfo);
        }
      });

      return {
        userConnectedMembers,
        nonConnectedMembers,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "メンバー情報の取得に失敗しました"
      );
    }
  }
);
