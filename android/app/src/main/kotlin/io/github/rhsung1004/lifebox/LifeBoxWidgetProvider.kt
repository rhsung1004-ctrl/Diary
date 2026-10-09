package io.github.rhsung1004.lifebox

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** 홈 화면 위젯: 오늘 일기 여부, 연속 기록, 진행 중 목표 2개 (앱 테마 색을 따라감) */
class LifeBoxWidgetProvider : HomeWidgetProvider() {

    /** 앱에서 넘겨준 색 (없으면 기본 색) */
    private class Palette(val bg: Int, val text: Int, val sub: Int, val accent: Int, val track: Int)

    private fun palette(context: Context, data: SharedPreferences): Palette {
        val mode = data.getString("mode", "system") ?: "system"
        val systemDark = (context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val dark = when (mode) {
            "dark" -> true
            "light" -> false
            else -> systemDark
        }
        val p = if (dark) "d" else "l"
        fun c(key: String, defRes: Int): Int =
            data.getString("c_${p}_$key", null)?.toLongOrNull()?.toInt() ?: context.getColor(defRes)
        return Palette(
            bg = c("bg", R.color.widget_bg),
            text = c("text", R.color.widget_text),
            sub = c("sub", R.color.widget_sub),
            accent = c("accent", R.color.widget_accent),
            track = c("track", R.color.widget_track),
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val dayFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val now = Calendar.getInstance()
        val today = dayFmt.format(now.time)
        val yesterday = dayFmt.format(Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }.time)

        val savedDay = widgetData.getString("saved_day", null)
        val savedDone = widgetData.getString("diary_done", "false") == "true"
        val savedStreak = widgetData.getString("streak", "0")?.toIntOrNull() ?: 0

        // 앱을 안 연 사이 날짜가 바뀌었을 수 있으므로 여기서 다시 판단
        val doneToday = savedDay == today && savedDone
        val streak = when (savedDay) {
            today -> savedStreak
            yesterday -> if (savedDone) savedStreak else 0
            else -> 0
        }
        val goalCount = widgetData.getString("goal_count", "0")?.toIntOrNull() ?: 0

        // 앱에서 넘겨준 언어와 문구 (없으면 한국어 기본값)
        val lang = widgetData.getString("lang", "ko") ?: "ko"
        fun t(key: String, def: String) = widgetData.getString(key, null) ?: def
        val dateLabel = when (lang) {
            "ja" -> SimpleDateFormat("M月d日 (E)", Locale.JAPANESE)
            "en" -> SimpleDateFormat("EEE, MMM d", Locale.ENGLISH)
            else -> SimpleDateFormat("M월 d일 (E)", Locale.KOREAN)
        }.format(now.time)

        val pal = palette(context, widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.lifebox_widget).apply {
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("lifebox://home")),
                )
                setOnClickPendingIntent(
                    R.id.widget_write,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("lifebox://diary/new")),
                )

                // 색: 배경(흰 둥근 사각형에 색 입히기), 글자, 강조색
                setInt(R.id.widget_bg, "setColorFilter", pal.bg)
                setTextColor(R.id.widget_date, pal.sub)
                setTextColor(R.id.widget_streak, pal.accent)
                setTextColor(R.id.widget_diary, pal.text)
                setTextColor(R.id.widget_goal1, pal.text)
                setTextColor(R.id.widget_goal2, pal.text)
                setTextColor(R.id.widget_write, pal.accent)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    for (bar in intArrayOf(R.id.widget_goal1_bar, R.id.widget_goal2_bar)) {
                        setColorStateList(bar, "setProgressTintList", ColorStateList.valueOf(pal.accent))
                        setColorStateList(bar, "setProgressBackgroundTintList", ColorStateList.valueOf(pal.track))
                    }
                }

                setTextViewText(R.id.widget_date, dateLabel)
                setTextViewText(
                    R.id.widget_streak,
                    if (streak > 0) t("t_streak", "🔥 {n}일 연속").replace("{n}", streak.toString()) else "",
                )
                setTextViewText(
                    R.id.widget_diary,
                    if (doneToday) t("t_done", "✓ 오늘 일기 완료") else t("t_todo", "오늘 일기를 아직 안 썼어요"),
                )
                setTextViewText(R.id.widget_write, t("t_write", "＋ 일기 쓰기"))
                setViewVisibility(R.id.widget_write, if (doneToday) View.GONE else View.VISIBLE)

                bindGoal(this, widgetData, 1, R.id.widget_goal1, R.id.widget_goal1_bar)
                bindGoal(this, widgetData, 2, R.id.widget_goal2, R.id.widget_goal2_bar)
                if (goalCount == 0) {
                    setTextViewText(R.id.widget_goal1, t("t_no_goals", "진행 중인 목표가 없어요"))
                    setViewVisibility(R.id.widget_goal1, View.VISIBLE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindGoal(views: RemoteViews, data: SharedPreferences, n: Int, textId: Int, barId: Int) {
        val title = data.getString("goal${n}_title", "") ?: ""
        val pct = data.getString("goal${n}_pct", "0")?.toIntOrNull() ?: 0
        if (title.isEmpty()) {
            views.setViewVisibility(textId, View.GONE)
            views.setViewVisibility(barId, View.GONE)
            return
        }
        views.setViewVisibility(textId, View.VISIBLE)
        views.setViewVisibility(barId, View.VISIBLE)
        views.setTextViewText(textId, "$title  ·  $pct%")
        views.setProgressBar(barId, 100, pct, false)
    }
}
