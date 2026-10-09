package io.github.rhsung1004.lifebox

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** 홈 화면 위젯: 오늘 일기 여부, 연속 기록, 진행 중 목표 2개 */
class LifeBoxWidgetProvider : HomeWidgetProvider() {

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
        val hidden = widgetData.getString("hidden", "false") == "true"
        val goalCount = widgetData.getString("goal_count", "0")?.toIntOrNull() ?: 0
        val dateLabel = SimpleDateFormat("M월 d일 (E)", Locale.KOREAN).format(now.time)

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
                setTextViewText(R.id.widget_date, dateLabel)
                setTextViewText(R.id.widget_streak, if (streak > 0) "🔥 ${streak}일 연속" else "")
                setTextViewText(R.id.widget_diary, if (doneToday) "✓ 오늘 일기 완료" else "오늘 일기를 아직 안 썼어요")
                setViewVisibility(R.id.widget_write, if (doneToday) View.GONE else View.VISIBLE)

                if (hidden) {
                    // 앱 잠금 중에는 목표 제목을 홈 화면에 드러내지 않음
                    setTextViewText(R.id.widget_goal1, "🔒 진행 중인 목표 ${goalCount}개")
                    setViewVisibility(R.id.widget_goal1, View.VISIBLE)
                    setViewVisibility(R.id.widget_goal1_bar, View.GONE)
                    setViewVisibility(R.id.widget_goal2, View.GONE)
                    setViewVisibility(R.id.widget_goal2_bar, View.GONE)
                } else {
                    bindGoal(this, widgetData, 1, R.id.widget_goal1, R.id.widget_goal1_bar)
                    bindGoal(this, widgetData, 2, R.id.widget_goal2, R.id.widget_goal2_bar)
                    if (goalCount == 0) {
                        setTextViewText(R.id.widget_goal1, "진행 중인 목표가 없어요")
                        setViewVisibility(R.id.widget_goal1, View.VISIBLE)
                    }
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
