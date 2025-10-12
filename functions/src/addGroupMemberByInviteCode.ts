import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {v4 as uuidv4} from "uuid";

interface NewMember {
  id: string | null;  // null = create new, string = link existing
  name: string;
  firebaseUid: string;
}

interface AddMemberRequest {
  code: string;
  newMember: NewMember;
}

interface AddMemberResponse {
  success: boolean;
  memberId: string;
  groupId: string;
}

/**
 * Add or link a group member by invite code
 * - If newMember.id is null: create new member
 * - If newMember.id exists: link existing member to firebaseUid
 *
 * Invite code is deleted after use (single-use)
 */
export const addGroupMemberByInviteCode = functions.https.onCall(
  async (request): Promise<AddMemberResponse> => {
    // Verify authentication
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "認証が必要です"
      );
    }

    const data = request.data as AddMemberRequest;
    const {code, newMember} = data;

    // Validate request
    if (!code || typeof code !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "招待コードが必要です"
      );
    }

    if (!newMember || !newMember.name || !newMember.firebaseUid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "メンバー情報が不正です"
      );
    }

    // Verify firebaseUid matches authenticated user
    if (newMember.firebaseUid !== request.auth.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "認証情報が一致しません"
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

      // Check max uses
      if (invite.maxUses && invite.currentUses >= invite.maxUses) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "この招待コードは使用回数の上限に達しています"
        );
      }

      const groupId = invite.groupId;

      // Check if user is already a member
      const existingMembersSnapshot = await db
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .where("firebaseUid", "==", newMember.firebaseUid)
        .where("deletedAt", "==", null)
        .limit(1)
        .get();

      if (!existingMembersSnapshot.empty) {
        throw new functions.https.HttpsError(
          "already-exists",
          "既にこのグループのメンバーです"
        );
      }

      let memberId: string;

      // Execute in transaction
      await db.runTransaction(async (transaction) => {
        if (newMember.id) {
          // Link existing member
          memberId = newMember.id;
          const memberRef = db
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .doc(memberId);

          const memberDoc = await transaction.get(memberRef);
          if (!memberDoc.exists) {
            throw new functions.https.HttpsError(
              "not-found",
              "指定されたメンバーが見つかりません"
            );
          }

          const memberData = memberDoc.data();
          if (memberData?.firebaseUid) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "このメンバーは既に認証されています"
            );
          }

          // Update member with firebaseUid and userId
          transaction.update(memberRef, {
            userId: newMember.firebaseUid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: newMember.firebaseUid,
          });
        } else {
          // Create new member with UUID
          memberId = uuidv4(); // Generate UUID
          const memberRef = db
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .doc(memberId); // Use UUID as document ID

          transaction.set(memberRef, {
            userId: newMember.firebaseUid,
            displayName: newMember.name,
            avatarURL: null,
            groupId: groupId,
            role: "member",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: newMember.firebaseUid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: newMember.firebaseUid,
            deletedAt: null,
            deletedBy: null,
          });
        }

        // Delete the invite code (single-use)
        transaction.delete(inviteDoc.ref);
      });

      return {
        success: true,
        memberId: memberId!,
        groupId: groupId,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      console.error("Error adding group member:", error);
      throw new functions.https.HttpsError(
        "internal",
        "メンバーの追加に失敗しました"
      );
    }
  }
);
